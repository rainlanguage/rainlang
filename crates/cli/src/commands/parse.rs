use crate::execute::Execute;
use crate::fork::NewForkedEvmCliArgs;
use crate::output::SupportedOutputEncoding;
use alloy::primitives::Address;
use anyhow::Result;
use anyhow::anyhow;
use clap::Args;
use rainlang_eval::eval::ForkParseArgs;
use rainlang_eval::fork::Forker;
use std::path::PathBuf;

/// CLI arguments for parsing a Rainlang expression.
#[derive(Args, Clone, Debug)]
pub struct ForkParseArgsCli {
    #[arg(long, help = "The address of the Rainlang contract")]
    rainlang: Address,

    #[arg(short, long, help = "The Rainlang string to parse")]
    rainlang_string: String,

    #[arg(short, long, help = "Decode errors using the openchain.xyz database")]
    decode_errors: bool,
}

/// CLI subcommand that parses a Rainlang expression into bytecode.
#[derive(Args, Clone)]
pub struct Parse {
    /// Output path. If not specified, the output is written to stdout.
    #[arg(short, long)]
    output_path: Option<PathBuf>,
    /// Output encoding. If not specified, the output is written in binary format.
    #[arg(short = 'E', long, default_value = "binary")]
    output_encoding: SupportedOutputEncoding,

    #[command(flatten)]
    forked_evm: NewForkedEvmCliArgs,

    #[command(flatten)]
    fork_parse_args: ForkParseArgsCli,
}

impl From<ForkParseArgsCli> for ForkParseArgs {
    fn from(args: ForkParseArgsCli) -> Self {
        ForkParseArgs {
            rainlang: args.rainlang,
            rainlang_string: args.rainlang_string,
            decode_errors: args.decode_errors,
        }
    }
}

impl Execute for Parse {
    async fn execute(&self) -> Result<()> {
        let forker = Forker::new_with_fork(self.forked_evm.clone().into(), None, None).await?;
        let result = forker.fork_parse(self.fork_parse_args.clone().into()).await;

        match result {
            Ok(res) => crate::output::output(
                &self.output_path,
                self.output_encoding.clone(),
                res.raw.result.to_owned().to_vec().as_slice(),
            ),
            Err(e) => Err(anyhow!(e)),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::fork::NewForkedEvmCliArgs;
    use rain_interpreter_test_fixtures::LocalEvm;

    #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
    async fn test_execute() {
        let local_evm = LocalEvm::new().await;

        let parse = Parse {
            output_path: None,
            output_encoding: SupportedOutputEncoding::Binary,
            forked_evm: NewForkedEvmCliArgs {
                fork_url: local_evm.url(),
                fork_block_number: None,
            },
            fork_parse_args: ForkParseArgsCli {
                rainlang: local_evm.rainlang,
                rainlang_string: "_: 1;".into(),
                decode_errors: false,
            },
        };

        let result = parse.execute().await;
        assert!(result.is_ok());
    }
}
