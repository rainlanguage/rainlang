use alloy::primitives::ruint::FromUintError;
#[cfg(not(target_family = "wasm"))]
use foundry_evm::{backend::DatabaseError, executors::RawCallResult};
use rain_error_decoding::{AbiDecodeFailedErrors, AbiDecodedErrorType};
use thiserror::Error;

/// Errors that can occur when calling a forked EVM.
#[derive(Debug, Error)]
pub enum ForkCallError {
    #[error("Executor error: {0}")]
    ExecutorError(String),
    #[cfg(not(target_family = "wasm"))]
    #[error("Call failed: {:#?}", .0)]
    Failed(Box<RawCallResult>),
    #[error("Typed error: {0}")]
    TypedError(String),
    #[error(transparent)]
    AbiDecodeFailed(#[from] AbiDecodeFailedErrors),
    #[error(transparent)]
    AbiDecodedError(#[from] AbiDecodedErrorType),
    #[error("Failed to deserialize serialized expression: {0}")]
    DeserializeFailed(String),
    #[error(transparent)]
    U64FromUint256(#[from] FromUintError<u64>),
    #[error(transparent)]
    Eyre(#[from] eyre::Report),
    #[error("Replay transaction error: {:#?}", .0)]
    ReplayTransactionError(#[from] ReplayTransactionError),
}

/// Errors specific to replaying a historical transaction.
#[derive(Debug, Error)]
pub enum ReplayTransactionError {
    #[error("Transaction not found for hash {0} and fork url {1}")]
    TransactionNotFound(String, String),
    #[error("No active fork found")]
    NoActiveFork,
    #[cfg(not(target_family = "wasm"))]
    #[error("Database error for hash {0} and fork url {1}: {2}")]
    DatabaseError(String, String, DatabaseError),
    #[error("No block number found in transaction for hash {0} and fork url {1}")]
    NoBlockNumberFound(String, String),
    #[error("No from address found in transaction for hash {0} and fork url {1}")]
    NoFromAddressFound(String, String),
    #[error("Cannot replay genesis block (block 0) transaction for hash {0} and fork url {1}")]
    GenesisBlockReplay(String, String),
}

#[cfg(not(target_family = "wasm"))]
impl From<RawCallResult> for ForkCallError {
    fn from(value: RawCallResult) -> Self {
        Self::Failed(Box::new(value))
    }
}
