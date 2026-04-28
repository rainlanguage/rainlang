use crate::error::{ForkCallError, ReplayTransactionError};
use alloy::consensus::Transaction;
use alloy::primitives::{Address, BlockNumber, U256};
use alloy::sol_types::SolCall;
use foundry_evm::traces::TraceMode;
use foundry_evm::{
    Env, EnvMut,
    backend::{Backend, DatabaseExt, JournaledState, LocalForkId},
    executors::{Executor, ExecutorBuilder, RawCallResult},
    fork::{CreateFork, ForkId, MultiFork},
    opts::EvmOpts,
};
use rain_error_decoding::AbiDecodedErrorType;
use revm::primitives::hardfork::SpecId;
use revm::primitives::{B256, TxKind};
use revm::{
    interpreter::InstructionResult,
    primitives::{Address as Addr, Bytes},
};
use std::{any::type_name, collections::HashMap};

/// Forker is thin wrapper around foundry for easily forking multiple evm
/// networks with in-memory cache that provides easy to use read/write
/// functionalities.
#[derive(Clone)]
pub struct Forker {
    pub executor: Executor,
    forks: HashMap<ForkId, (LocalForkId, SpecId, BlockNumber)>,
}

/// Result of an alloy-typed call containing both the raw EVM result and the
/// ABI-decoded return value.
pub struct ForkTypedReturn<C: SolCall> {
    /// The raw EVM call result including traces and exit reason.
    pub raw: RawCallResult,
    /// The ABI-decoded return value.
    pub typed_return: C::Return,
}

/// Configuration for creating a new forked EVM instance.
#[derive(Debug, Clone)]
pub struct NewForkedEvm {
    /// RPC URL of the network to fork.
    pub fork_url: String,
    /// Optional block number to fork from. Uses latest if `None`.
    pub fork_block_number: Option<BlockNumber>,
}

fn mk_journaled_state(spec_id: SpecId) -> JournaledState {
    let mut journaled_state = JournaledState::new();
    journaled_state.set_spec_id(spec_id);
    journaled_state
}

// NOTE: there is a trait for this in foundry-evm-core but it's not exposed
// through the meta crate foundry-evm
fn mk_env_mut(env: &mut Env) -> EnvMut<'_> {
    EnvMut {
        block: &mut env.evm_env.block_env,
        cfg: &mut env.evm_env.cfg_env,
        tx: &mut env.tx,
    }
}

impl Forker {
    /// Creates a new empty instance of `Forker`.
    pub fn new() -> eyre::Result<Forker> {
        let db = Backend::new(MultiFork::new().0, None)?;
        let builder = ExecutorBuilder::default()
            .inspectors(|stack| stack.trace_mode(TraceMode::Call.with_debug(false)));
        Ok(Self {
            executor: builder.build(Env::default(), db),
            forks: HashMap::new(),
        })
    }

    /// Creates a new instance of `Forker` with the specified fork URL and optional fork block number.
    ///
    /// # Arguments
    ///
    /// * `args` - Fork configuration containing URL and optional block number.
    /// * `env` - Optional EVM environment override.
    /// * `gas_limit` - Optional gas limit override.
    ///
    /// # Returns
    ///
    /// A new instance of `Forker`.
    ///
    /// # Examples
    ///
    /// ```ignore
    /// use rainlang_eval::fork::{Forker, NewForkedEvm};
    ///
    /// let args = NewForkedEvm {
    ///     fork_url: "https://example.com/fork".to_owned(),
    ///     fork_block_number: Some(12345u64),
    /// };
    /// let forker = Forker::new_with_fork(args, None, None).await;
    /// ```
    pub async fn new_with_fork(
        args: NewForkedEvm,
        env: Option<Env>,
        gas_limit: Option<u64>,
    ) -> Result<Forker, ForkCallError> {
        let NewForkedEvm {
            fork_url,
            fork_block_number,
        } = args;
        let fork_id = ForkId::new(&fork_url, fork_block_number);
        let evm_opts = EvmOpts {
            fork_url: Some(fork_url.to_string()),
            fork_block_number,
            env: foundry_evm::opts::Env {
                chain_id: None,
                code_size_limit: None,
                gas_limit: u64::MAX.into(),
                ..Default::default()
            },
            memory_limit: u64::MAX,
            ..Default::default()
        };

        let create_fork = CreateFork {
            url: fork_url.clone(),
            enable_caching: true,
            env: evm_opts.fork_evm_env(&fork_url).await?.0,
            evm_opts,
        };
        let block_number = if let Some(block_number) = fork_block_number {
            block_number
        } else {
            create_fork.env.evm_env.block_env.number
        };

        let db = Backend::spawn(Some(create_fork.clone()))?;

        let builder = if let Some(gas) = gas_limit {
            ExecutorBuilder::default().gas_limit(gas)
        } else {
            ExecutorBuilder::default()
        };
        let builder =
            builder.inspectors(|stack| stack.trace_mode(TraceMode::Call.with_debug(false)));

        let mut forks_map = HashMap::new();
        forks_map.insert(fork_id, (U256::from(0), SpecId::default(), block_number));
        Ok(Self {
            executor: builder.build(env.unwrap_or(create_fork.env.clone()), db),
            forks: forks_map,
        })
    }

    /// Adds new fork and sets it as active or if the fork already exists, selects it as active.
    /// Does nothing if the fork is already the active fork.
    pub async fn add_or_select(
        &mut self,
        args: NewForkedEvm,
        env: Option<Env>,
    ) -> Result<(), ForkCallError> {
        if self.forks.is_empty() {
            let forker = Self::new_with_fork(args, env, None).await?;
            self.executor = forker.executor;
            self.forks = forker.forks;
            return Ok(());
        }
        let NewForkedEvm {
            fork_url,
            fork_block_number,
        } = args;
        let fork_id = ForkId::new(&fork_url, fork_block_number);
        if let Some((local_fork_id, spec_id, _)) = self.forks.get(&fork_id) {
            if self.executor.backend().is_active_fork(*local_fork_id) {
                Ok(())
            } else {
                let mut journaled_state = mk_journaled_state(*spec_id);
                self.executor
                    .backend_mut()
                    .select_fork(
                        *local_fork_id,
                        &mut mk_env_mut(&mut env.unwrap_or_default()),
                        &mut journaled_state,
                    )
                    .map(|_| ())
                    .map_err(|e| ForkCallError::ExecutorError(e.to_string()))
            }
        } else {
            let evm_opts = EvmOpts {
                fork_url: Some(fork_url.to_string()),
                fork_block_number,
                env: foundry_evm::opts::Env {
                    chain_id: None,
                    code_size_limit: None,
                    gas_limit: u64::MAX.into(),
                    ..Default::default()
                },
                memory_limit: u64::MAX,
                ..Default::default()
            };
            let create_fork = CreateFork {
                url: fork_url.to_string(),
                enable_caching: true,
                env: evm_opts.fork_evm_env(&fork_url).await?.0,
                evm_opts,
            };
            let block_number = if let Some(block_number) = fork_block_number {
                block_number
            } else {
                create_fork.env.evm_env.block_env.number
            };

            self.forks.insert(
                fork_id,
                (
                    U256::from(self.forks.len()),
                    SpecId::default(),
                    block_number,
                ),
            );

            self.executor
                .backend_mut()
                .create_select_fork(
                    create_fork,
                    &mut mk_env_mut(&mut env.unwrap_or_default()),
                    &mut mk_journaled_state(SpecId::default()),
                )
                .map(|_| ())
                .map_err(|e| ForkCallError::ExecutorError(e.to_string()))
        }
    }

    /// Calls the forked EVM without committing to state using alloy typed arguments.
    /// # Arguments
    /// * `from_address` - The address to call from.
    /// * `to_address` - The address to call to.
    /// * `call` - The call to make.
    /// * `decode_error` - Whether to decode revert data using the error selector registry.
    /// # Returns
    /// A result containing the raw call result and the typed return.
    pub async fn alloy_call<T: SolCall>(
        &self,
        from_address: Address,
        to_address: Address,
        call: T,
        decode_error: bool,
    ) -> Result<ForkTypedReturn<T>, ForkCallError> {
        let raw = self.call(
            from_address.as_slice(),
            to_address.as_slice(),
            &call.abi_encode(),
        )?;

        if decode_error && raw.exit_reason == InstructionResult::Revert {
            // decode result bytes to error selectors if it was a revert
            return Err(ForkCallError::AbiDecodedError(
                AbiDecodedErrorType::selector_registry_abi_decode(&raw.result, None).await?,
            ));
        }

        if !raw.exit_reason.is_ok() {
            return Err(raw.into());
        }

        let typed_return = T::abi_decode_returns(&raw.result.0).map_err(|e| {
            ForkCallError::TypedError(format!(
                "Call:{:?} Error:{:?} Raw:{:?}",
                type_name::<T>(),
                e,
                raw
            ))
        })?;
        Ok(ForkTypedReturn { raw, typed_return })
    }

    /// Writes to the forked EVM using alloy typed arguments.
    /// # Arguments
    /// * `from_address` - The address to call from.
    /// * `to_address` - The address to call to.
    /// * `call` - The call to make.
    /// * `value` - The value to send with the call.
    /// * `decode_error` - Whether to decode revert data using the error selector registry.
    /// # Returns
    /// A result containing the raw call result and the typed return.
    pub async fn alloy_call_committing<T: SolCall>(
        &mut self,
        from_address: Address,
        to_address: Address,
        call: T,
        value: U256,
        decode_error: bool,
    ) -> Result<ForkTypedReturn<T>, ForkCallError> {
        let raw: RawCallResult = self.call_committing(
            from_address.as_slice(),
            to_address.as_slice(),
            &call.abi_encode(),
            value,
        )?;

        if decode_error && raw.exit_reason == InstructionResult::Revert {
            // decode result bytes to error selectors if it was a revert
            return Err(ForkCallError::AbiDecodedError(
                AbiDecodedErrorType::selector_registry_abi_decode(&raw.result, None).await?,
            ));
        }

        if !raw.exit_reason.is_ok() {
            return Err(raw.into());
        }

        let typed_return = T::abi_decode_returns(&raw.result.0).map_err(|e| {
            ForkCallError::TypedError(format!(
                "Call:{:?} Error:{:?} Raw:{:?}",
                type_name::<T>(),
                e,
                raw
            ))
        })?;
        Ok(ForkTypedReturn { raw, typed_return })
    }

    /// Calls the forked EVM without committing to state.
    /// # Arguments
    /// * `from_address` - The address to call from.
    /// * `to_address` - The address to call to.
    /// * `calldata` - The calldata.
    /// # Returns
    /// A result containing the raw call result.
    pub fn call(
        &self,
        from_address: &[u8],
        to_address: &[u8],
        calldata: &[u8],
    ) -> Result<RawCallResult, ForkCallError> {
        if from_address.len() != 20 || to_address.len() != 20 {
            return Err(ForkCallError::ExecutorError("invalid address!".to_owned()));
        }

        self.executor
            .call_raw(
                Addr::from_slice(from_address),
                Addr::from_slice(to_address),
                Bytes::copy_from_slice(calldata),
                U256::from(0),
            )
            .map_err(|e| ForkCallError::ExecutorError(e.to_string()))
    }

    /// Writes to the forked EVM.
    /// # Arguments
    /// * `from_address` - The address to call from.
    /// * `to_address` - The address to call to.
    /// * `calldata` - The calldata.
    /// * `value` - The value to send with the call.
    /// # Returns
    /// A result containing the raw call result.
    pub fn call_committing(
        &mut self,
        from_address: &[u8],
        to_address: &[u8],
        calldata: &[u8],
        value: U256,
    ) -> Result<RawCallResult, ForkCallError> {
        if from_address.len() != 20 || to_address.len() != 20 {
            return Err(ForkCallError::ExecutorError("invalid address!".to_owned()));
        }

        let result = self
            .executor
            .transact_raw(
                Addr::from_slice(from_address),
                Addr::from_slice(to_address),
                Bytes::copy_from_slice(calldata),
                value,
            )
            .map_err(|e| ForkCallError::ExecutorError(e.to_string()));

        // remove to_address from persisted accounts
        self.executor
            .backend_mut()
            .remove_persistent_account(&Addr::from_slice(to_address));

        result
    }

    /// resets the active fork to a given block number or to original fork block number if not provided
    pub fn roll_fork(
        &mut self,
        block_number: Option<BlockNumber>,
        env: Option<Env>,
    ) -> Result<(), ForkCallError> {
        let active_fork_local_id = self
            .executor
            .backend()
            .active_fork_id()
            .ok_or(ForkCallError::ExecutorError("no active fork!".to_owned()))?;
        let mut org_block_number = None;
        let mut spec_id = SpecId::default();
        for (local_id, sid, bnumber) in self.forks.values() {
            if *local_id == active_fork_local_id {
                spec_id = *sid;
                org_block_number = Some(*bnumber);
                break;
            }
        }
        let org_block_number =
            org_block_number.ok_or(ForkCallError::ExecutorError("no active fork!".to_owned()))?;
        let block_number = block_number.unwrap_or(org_block_number);

        self.executor.env_mut().evm_env.block_env.number = block_number;

        self.executor
            .backend_mut()
            .roll_fork(
                Some(active_fork_local_id),
                block_number,
                &mut mk_env_mut(&mut env.unwrap_or_default()),
                &mut mk_journaled_state(spec_id),
            )
            .map_err(|v| ForkCallError::ExecutorError(v.to_string()))
    }

    /// Replays a transaction from the forked EVM.
    /// # Arguments
    /// * `tx_hash` - The transaction hash.
    /// # Returns
    /// A result containing the raw call result.
    pub async fn replay_transaction(
        &mut self,
        tx_hash: B256,
    ) -> Result<RawCallResult, ForkCallError> {
        let fork_url = self
            .executor
            .backend()
            .active_fork_url()
            .ok_or(ReplayTransactionError::NoActiveFork)?;

        // get the transaction
        let shared_backend = &self
            .executor
            .backend()
            .active_fork_db()
            .ok_or(ReplayTransactionError::NoActiveFork)?
            .db;
        let full_tx = shared_backend.get_transaction(tx_hash).map_err(|e| {
            ReplayTransactionError::DatabaseError(tx_hash.to_string(), fork_url.clone(), e)
        })?;

        // get the block number from the transaction
        let block_number =
            full_tx
                .block_number
                .ok_or(ReplayTransactionError::NoBlockNumberFound(
                    tx_hash.to_string(),
                    fork_url.clone(),
                ))?;

        // get the block
        let block = shared_backend.get_full_block(block_number).map_err(|e| {
            ReplayTransactionError::DatabaseError(block_number.to_string(), fork_url.clone(), e)
        })?;

        self.add_or_select(
            NewForkedEvm {
                fork_url: fork_url.clone(),
                fork_block_number: Some(block_number.checked_sub(1).ok_or(
                    ReplayTransactionError::GenesisBlockReplay(
                        tx_hash.to_string(),
                        fork_url.clone(),
                    ),
                )?),
            },
            None,
        )
        .await?;

        // matching env to the env from the block the transaction is in
        self.executor.env_mut().evm_env.block_env.number = block_number;
        self.executor.env_mut().evm_env.block_env.timestamp = block.header.timestamp;
        self.executor.env_mut().evm_env.block_env.beneficiary = block.header.beneficiary;
        self.executor.env_mut().evm_env.block_env.difficulty = block.header.difficulty;
        self.executor.env_mut().evm_env.block_env.prevrandao =
            Some(block.header.mix_hash.unwrap_or_default());
        self.executor.env_mut().evm_env.block_env.basefee =
            block.header.base_fee_per_gas.unwrap_or_default();
        self.executor.env_mut().evm_env.block_env.gas_limit = block.header.gas_limit;

        let active_fork_local_id = self
            .executor
            .backend()
            .active_fork_id()
            .ok_or(ForkCallError::ExecutorError("no active fork!".to_owned()))?;

        let mut journaled_state = JournaledState::new();

        let env = self.executor.env().clone();

        // replay all transactions that came before
        let tx = self.executor.backend_mut().replay_until(
            active_fork_local_id,
            env,
            tx_hash,
            &mut journaled_state,
        )?;

        let res = match tx {
            // if to field is None, it means the tx was a contract deployment, see 'revm::primitives::TxKind'
            Some(tx) => match tx.inner.kind() {
                TxKind::Call(to) => self.call(
                    tx.inner.signer().as_slice(),
                    to.as_slice(),
                    tx.inner.input(),
                )?,
                TxKind::Create => {
                    self.call(tx.inner.signer().as_slice(), &[0u8; 20], tx.inner.input())?
                }
            },
            None => {
                return Err(ForkCallError::ReplayTransactionError(
                    ReplayTransactionError::TransactionNotFound(tx_hash.to_string(), fork_url),
                ));
            }
        };

        Ok(res)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::namespace::qualify_namespace;
    use alloy::eips::BlockNumberOrTag;
    use alloy::sol;
    use alloy::{
        primitives::{FixedBytes, U256},
        providers::Provider,
    };
    use rainlang_bindings::IInterpreterStoreV3::{getCall, setCall};
    use rainlang_test_fixtures::LocalEvm;

    sol! {
        interface IERC20 {
            function balanceOf(address account) external view returns (uint256);
            function transfer(address to, uint256 amount) external returns (bool);
            function allowance(address owner, address spender) external view returns (uint256);
            function approve(address spender, uint256 amount) external returns (bool);
            function transferFrom(address from, address to, uint256 amount) external returns (bool);
        }
    }

    sol! {
        interface IERC165 {
            function supportsInterface(bytes4 interfaceId) external view returns (bool);
        }
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
    async fn test_forker_read() {
        let local_evm = LocalEvm::new().await;
        let deployer = *local_evm.deployer.address();
        let args = NewForkedEvm {
            fork_url: local_evm.url(),
            fork_block_number: None,
        };

        let forker = Forker::new_with_fork(args, None, None).await.unwrap();

        // Call supportsInterface(IERC165) on the deployer to verify alloy_call works.
        let call = IERC165::supportsInterfaceCall {
            interfaceId: alloy::primitives::FixedBytes([0x01, 0xff, 0xc9, 0xa7]),
        };
        let result = forker
            .alloy_call(Address::default(), deployer, call, false)
            .await
            .unwrap();
        assert!(result.typed_return);
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
    async fn test_forker_write() {
        let local_evm = LocalEvm::new().await;
        let args = NewForkedEvm {
            fork_url: local_evm.url(),
            fork_block_number: None,
        };
        let mut forker = Forker::new_with_fork(args, None, None).await.unwrap();

        let from_address = Address::repeat_byte(0x02);
        let store_address = *local_evm.store.address();

        let namespace = U256::from(1);
        let key = <FixedBytes<32>>::left_padding_from(&[3u8]);
        let value = <FixedBytes<32>>::left_padding_from(&[4u8]);
        let _set = forker
            .alloy_call_committing(
                from_address,
                store_address,
                setCall {
                    namespace,
                    kvs: vec![key, value],
                },
                U256::from(0),
                false,
            )
            .await
            .unwrap();

        let fully_quallified_namespace = qualify_namespace(namespace.into(), from_address);

        let get = forker
            .alloy_call(
                from_address,
                store_address,
                getCall {
                    namespace: fully_quallified_namespace.into(),
                    key: <FixedBytes<32>>::left_padding_from(&[3u8]),
                },
                false,
            )
            .await
            .unwrap()
            .typed_return;
        assert_eq!(value, get);
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
    async fn test_multi_fork_read_write_switch_reset() -> Result<(), ForkCallError> {
        let local_evm1 = LocalEvm::new_with_tokens(1).await;
        let local_evm1_token = *local_evm1.tokens[0].address();
        let local_evm1_token_holder = local_evm1.anvil.addresses()[0];
        let args = NewForkedEvm {
            fork_url: local_evm1.url(),
            fork_block_number: None,
        };
        let mut forker = Forker::new_with_fork(args, None, None).await.unwrap();

        let from_address = Address::default();
        let to_address = local_evm1_token;
        let call = IERC20::balanceOfCall {
            account: local_evm1_token_holder,
        };
        let result = forker
            .alloy_call(from_address, to_address, call, false)
            .await
            .unwrap();
        let old_balance = result.typed_return;
        let polygon_old_balance = result.typed_return;

        let from_address = local_evm1_token_holder;
        let to_address = local_evm1_token;
        let send_amount = U256::from(0xffu64);
        let transfer_call = IERC20::transferCall {
            to: Address::repeat_byte(0x2),
            amount: send_amount,
        };
        forker
            .alloy_call_committing(
                from_address,
                to_address,
                transfer_call,
                U256::from(0),
                false,
            )
            .await
            .unwrap();

        let from_address = Address::default();
        let to_address = local_evm1_token;
        let call = IERC20::balanceOfCall {
            account: local_evm1_token_holder,
        };
        let result = forker
            .alloy_call(from_address, to_address, call, false)
            .await
            .unwrap();
        let new_balance = result.typed_return;
        assert_eq!(new_balance, old_balance - send_amount);
        let polygon_balance = new_balance;

        // switch fork
        let local_evm2 = LocalEvm::new_with_tokens(1).await;
        let local_evm2_token = *local_evm2.tokens[0].address();
        let local_evm2_token_holder = local_evm2.anvil.addresses()[0];
        let args = NewForkedEvm {
            fork_url: local_evm2.url(),
            fork_block_number: None,
        };
        forker.add_or_select(args, None).await?;

        let from_address = Address::default();
        let to_address = local_evm2_token;
        let call = IERC20::balanceOfCall {
            account: local_evm2_token_holder,
        };
        let result = forker
            .alloy_call(from_address, to_address, call, false)
            .await
            .unwrap();
        let old_balance = result.typed_return;

        let from_address = local_evm2_token_holder;
        let to_address = local_evm2_token;
        let send_amount = U256::from(0xffu64);
        let transfer_call = IERC20::transferCall {
            to: Address::repeat_byte(0x2),
            amount: send_amount,
        };
        forker
            .alloy_call_committing(
                from_address,
                to_address,
                transfer_call,
                U256::from(0),
                false,
            )
            .await
            .unwrap();

        let from_address = Address::default();
        let to_address = local_evm2_token;
        let call = IERC20::balanceOfCall {
            account: local_evm2_token_holder,
        };
        let result = forker
            .alloy_call(from_address, to_address, call, false)
            .await
            .unwrap();
        let new_balance = result.typed_return;
        assert_eq!(new_balance, old_balance - send_amount);

        // switch fork back to fork1
        let args = NewForkedEvm {
            fork_url: local_evm1.url(),
            fork_block_number: None,
        };
        forker.add_or_select(args, None).await?;

        let from_address = Address::default();
        let to_address = local_evm1_token;
        let call = IERC20::balanceOfCall {
            account: local_evm1_token_holder,
        };
        let result = forker
            .alloy_call(from_address, to_address, call, false)
            .await
            .unwrap();
        let balance = result.typed_return;
        assert_eq!(balance, polygon_balance);

        // reset fork
        forker.roll_fork(None, None)?;
        let call = IERC20::balanceOfCall {
            account: local_evm1_token_holder,
        };
        let result = forker
            .alloy_call(from_address, to_address, call, false)
            .await
            .unwrap();
        let balance = result.typed_return;
        assert_eq!(balance, polygon_old_balance);

        Ok(())
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
    async fn test_fork_rolls() {
        // we need to roll the fork forwards and check that the env block number is updated
        let local_evm = LocalEvm::new().await;
        let block_number = local_evm.provider.get_block_number().await.unwrap() - 2;
        let args = NewForkedEvm {
            fork_url: local_evm.url(),
            fork_block_number: Some(block_number),
        };
        let mut forker = Forker::new_with_fork(args, None, None).await.unwrap();

        // check the env block number is the same as the fork block number
        assert_eq!(forker.executor.env().evm_env.block_env.number, block_number);

        // roll the fork forwards by 1 block
        forker.roll_fork(Some(block_number + 1), None).unwrap();

        // check the env block number is updated
        assert_eq!(
            forker.executor.env().evm_env.block_env.number,
            block_number + 1
        );
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
    async fn test_fork_replay() {
        let local_evm = LocalEvm::new().await;
        let block_number = local_evm.provider.get_block_number().await.unwrap();
        let tx_hash = local_evm
            .provider
            .get_block_by_number(BlockNumberOrTag::Number(block_number - 2))
            .await
            .unwrap()
            .unwrap()
            .transactions
            .as_hashes()
            .unwrap()[0];
        let mut forker = Forker::new_with_fork(
            NewForkedEvm {
                fork_url: local_evm.url(),
                fork_block_number: None,
            },
            None,
            None,
        )
        .await
        .unwrap();

        let replay_result = forker.replay_transaction(tx_hash).await.unwrap();

        assert!(replay_result.env.tx.caller == local_evm.anvil.addresses()[0]);
        assert!(replay_result.exit_reason.is_ok());
    }

    #[test]
    fn test_call_invalid_from_address_too_short() {
        let forker = Forker::new().unwrap();
        let result = forker.call(&[0u8; 19], &[0u8; 20], &[]);
        assert!(
            matches!(result, Err(ForkCallError::ExecutorError(ref msg)) if msg == "invalid address!")
        );
    }

    #[test]
    fn test_call_invalid_from_address_too_long() {
        let forker = Forker::new().unwrap();
        let result = forker.call(&[0u8; 21], &[0u8; 20], &[]);
        assert!(
            matches!(result, Err(ForkCallError::ExecutorError(ref msg)) if msg == "invalid address!")
        );
    }

    #[test]
    fn test_call_invalid_from_address_empty() {
        let forker = Forker::new().unwrap();
        let result = forker.call(&[], &[0u8; 20], &[]);
        assert!(
            matches!(result, Err(ForkCallError::ExecutorError(ref msg)) if msg == "invalid address!")
        );
    }

    #[test]
    fn test_call_invalid_to_address_too_short() {
        let forker = Forker::new().unwrap();
        let result = forker.call(&[0u8; 20], &[0u8; 19], &[]);
        assert!(
            matches!(result, Err(ForkCallError::ExecutorError(ref msg)) if msg == "invalid address!")
        );
    }

    #[test]
    fn test_call_invalid_to_address_too_long() {
        let forker = Forker::new().unwrap();
        let result = forker.call(&[0u8; 20], &[0u8; 21], &[]);
        assert!(
            matches!(result, Err(ForkCallError::ExecutorError(ref msg)) if msg == "invalid address!")
        );
    }

    #[test]
    fn test_call_invalid_to_address_empty() {
        let forker = Forker::new().unwrap();
        let result = forker.call(&[0u8; 20], &[], &[]);
        assert!(
            matches!(result, Err(ForkCallError::ExecutorError(ref msg)) if msg == "invalid address!")
        );
    }

    #[test]
    fn test_call_committing_invalid_from_address() {
        let mut forker = Forker::new().unwrap();
        let result = forker.call_committing(&[0u8; 19], &[0u8; 20], &[], U256::ZERO);
        assert!(
            matches!(result, Err(ForkCallError::ExecutorError(ref msg)) if msg == "invalid address!")
        );
    }

    #[test]
    fn test_call_committing_invalid_to_address() {
        let mut forker = Forker::new().unwrap();
        let result = forker.call_committing(&[0u8; 20], &[0u8; 21], &[], U256::ZERO);
        assert!(
            matches!(result, Err(ForkCallError::ExecutorError(ref msg)) if msg == "invalid address!")
        );
    }

    #[test]
    fn test_call_committing_both_addresses_invalid() {
        let mut forker = Forker::new().unwrap();
        let result = forker.call_committing(&[], &[], &[], U256::ZERO);
        assert!(
            matches!(result, Err(ForkCallError::ExecutorError(ref msg)) if msg == "invalid address!")
        );
    }

    #[test]
    fn test_roll_fork_no_active_fork() {
        let mut forker = Forker::new().unwrap();
        let result = forker.roll_fork(None, None);
        assert!(
            matches!(result, Err(ForkCallError::ExecutorError(ref msg)) if msg == "no active fork!")
        );
    }

    #[test]
    fn test_roll_fork_no_active_fork_with_block_number() {
        let mut forker = Forker::new().unwrap();
        let result = forker.roll_fork(Some(100), None);
        assert!(
            matches!(result, Err(ForkCallError::ExecutorError(ref msg)) if msg == "no active fork!")
        );
    }

    /// Forker::new() creates a valid empty forker, and add_or_select on an
    /// empty forker populates it via the is_empty branch.
    #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
    async fn test_forker_new_then_add_or_select() {
        let local_evm = LocalEvm::new().await;
        let deployer = *local_evm.deployer.address();
        let mut forker = Forker::new().unwrap();
        assert!(forker.forks.is_empty());

        forker
            .add_or_select(
                NewForkedEvm {
                    fork_url: local_evm.url(),
                    fork_block_number: None,
                },
                None,
            )
            .await
            .unwrap();

        assert!(!forker.forks.is_empty());

        // Verify the fork is usable by making a call.
        let call = IERC165::supportsInterfaceCall {
            interfaceId: alloy::primitives::FixedBytes([0x01, 0xff, 0xc9, 0xa7]),
        };
        let result = forker
            .alloy_call(Address::default(), deployer, call, false)
            .await
            .unwrap();
        assert!(result.typed_return);
    }
}
