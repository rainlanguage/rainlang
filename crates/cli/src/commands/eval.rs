use crate::execute::Execute;
use crate::fork::NewForkedEvmCliArgs;
use crate::output::SupportedOutputEncoding;
use alloy::primitives::{Address, U256};
use anyhow::Context;
use anyhow::Result;
use anyhow::anyhow;
use clap::Args;
use rainlang_bindings::IInterpreterStoreV3::FullyQualifiedNamespace;
use rainlang_eval::trace::RainEvalResult;
use rainlang_eval::{eval::ForkEvalArgs, fork::Forker};
use std::path::PathBuf;

/// CLI arguments for evaluating a Rainlang expression.
#[derive(Args, Clone, Debug)]
pub struct ForkEvalCliArgs {
    #[arg(short, long, help = "The Rainlang string to parse")]
    pub rainlang_string: String,

    #[arg(short, long, help = "The source index")]
    pub source_index: u16,

    #[arg(long, help = "The address of the Rainlang contract")]
    pub rainlang: Address,

    #[arg(short, long, help = "The namespace")]
    pub namespace: String,

    // Accept context as a vector of string key-value pairs
    #[arg(
        short,
        long,
        help = "The context in key=value format, key is the context column name and value is the context rows as a comma separated list"
    )]
    pub context: Vec<String>,

    #[arg(short, long, help = "Decode errors using the openchain.xyz database")]
    pub decode_errors: bool,

    // Accept inputs vector as array of uint256
    #[arg(
        short,
        long,
        help = "The inputs vector which are prepopulated stack items"
    )]
    pub inputs: Option<Vec<U256>>,

    // Accept state overlay vector as array of uint256
    #[arg(
        short,
        long,
        help = "The state overlay vector which applies to the state before evaluation to facilitate 'what if' analysis"
    )]
    pub state_overlay: Option<Vec<U256>>,
}

impl TryFrom<ForkEvalCliArgs> for ForkEvalArgs {
    type Error = anyhow::Error;

    fn try_from(args: ForkEvalCliArgs) -> Result<Self> {
        let namespace = parse_int_or_hex(&args.namespace).context("Invalid namespace format")?;

        let context = args
            .context
            .into_iter()
            .map(|ctx_str| {
                ctx_str
                    .split(',')
                    .map(|v| parse_int_or_hex(v).context("Invalid context value"))
                    .collect::<Result<Vec<U256>>>()
            })
            .collect::<Result<Vec<Vec<U256>>>>()?;

        Ok(ForkEvalArgs {
            rainlang_string: args.rainlang_string,
            source_index: args.source_index,
            rainlang: args.rainlang,
            namespace: FullyQualifiedNamespace::from(namespace),
            context,
            decode_errors: args.decode_errors,
            inputs: args.inputs.unwrap_or_default(),
            state_overlay: args.state_overlay.unwrap_or_default(),
        })
    }
}

// Helper function to parse a string as either integer or hex-encoded value
fn parse_int_or_hex(value: &str) -> Result<U256> {
    if value.starts_with("0x") || value.starts_with("0X") {
        U256::from_str_radix(&value[2..], 16).map_err(|e| e.into())
    } else {
        value.parse::<U256>().map_err(|e| e.into())
    }
}

/// CLI subcommand that evaluates a Rainlang expression against a forked EVM.
#[derive(Args, Clone)]
pub struct Eval {
    /// Output path. If not specified, the output is written to stdout.
    #[arg(short, long)]
    output_path: Option<PathBuf>,

    #[command(flatten)]
    forked_evm: NewForkedEvmCliArgs,

    #[command(flatten)]
    fork_eval_args: ForkEvalCliArgs,
}

impl Execute for Eval {
    async fn execute(&self) -> Result<()> {
        let forker = Forker::new_with_fork(self.forked_evm.clone().into(), None, None).await?;
        let result = forker
            .fork_eval(self.fork_eval_args.clone().try_into()?)
            .await;

        match result {
            Ok(res) => {
                let rain_eval_result: RainEvalResult = res.try_into().map_err(
                    |e: rainlang_eval::trace::RainEvalResultFromRawCallResultError| anyhow!(e),
                )?;
                crate::output::output(
                    &self.output_path,
                    SupportedOutputEncoding::Binary,
                    format!("{:#?}", rain_eval_result).as_bytes(),
                )
            }
            Err(e) => Err(anyhow!(e)),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rain_interpreter_test_fixtures::LocalEvm;

    #[test]
    fn test_parse_int_or_hex() {
        assert_eq!(parse_int_or_hex("123").unwrap(), U256::from(123));
        assert_eq!(parse_int_or_hex("0xabc").unwrap(), U256::from(2748));
        assert_eq!(parse_int_or_hex("0XFF").unwrap(), U256::from(255));
        assert!(parse_int_or_hex("invalid").is_err());
    }

    fn simple_cli_args() -> ForkEvalCliArgs {
        ForkEvalCliArgs {
            rainlang_string: "_: 1;".into(),
            source_index: 0,
            rainlang: Address::ZERO,
            namespace: "0x0".into(),
            context: vec![],
            decode_errors: false,
            inputs: None,
            state_overlay: None,
        }
    }

    #[test]
    fn test_try_from_invalid_namespace() {
        let mut args = simple_cli_args();
        args.namespace = "not_a_number".into();
        let result = ForkEvalArgs::try_from(args);
        assert!(result.is_err());
        let err = result.unwrap_err().to_string();
        assert!(
            err.contains("Invalid namespace format"),
            "expected 'Invalid namespace format', got: {err}"
        );
    }

    #[test]
    fn test_try_from_invalid_context_value() {
        let mut args = simple_cli_args();
        args.context = vec!["123,bad_value,456".into()];
        let result = ForkEvalArgs::try_from(args);
        assert!(result.is_err());
        let err = result.unwrap_err().to_string();
        assert!(
            err.contains("Invalid context value"),
            "expected 'Invalid context value', got: {err}"
        );
    }

    #[test]
    fn test_try_from_valid() {
        let mut args = simple_cli_args();
        args.namespace = "0xff".into();
        args.context = vec!["1,2,3".into(), "0xa,0xb".into()];
        let result = ForkEvalArgs::try_from(args);
        assert!(result.is_ok());
        let eval_args = result.unwrap();
        assert_eq!(eval_args.context.len(), 2);
        assert_eq!(
            eval_args.context[0],
            vec![U256::from(1), U256::from(2), U256::from(3)]
        );
        assert_eq!(eval_args.context[1], vec![U256::from(0xa), U256::from(0xb)]);
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
    async fn test_execute() {
        let local_evm = LocalEvm::new().await;

        let eval = Eval {
            output_path: None,
            forked_evm: NewForkedEvmCliArgs {
                fork_url: local_evm.url(),
                fork_block_number: None,
            },
            fork_eval_args: ForkEvalCliArgs {
                rainlang_string: r"_: 12, _: context<0 0>(), _:context<0 1>();".into(),
                source_index: 0,
                rainlang: local_evm.rainlang,
                namespace: "0x123".into(),
                context: vec!["0x06,99".into()],
                decode_errors: true,
                inputs: None,
                state_overlay: None,
            },
        };

        let result = eval.execute().await;
        assert!(result.is_ok());
    }
}
