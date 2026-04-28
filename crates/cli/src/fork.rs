use alloy::primitives::BlockNumber;
use clap::Args;
use rainlang_eval::fork::NewForkedEvm;

/// CLI arguments for connecting to a forked EVM via RPC.
#[derive(Args, Clone, Debug)]
pub struct NewForkedEvmCliArgs {
    #[arg(short = 'i', long, help = "RPC url for the fork")]
    pub fork_url: String,
    #[arg(short = 'b', long, help = "Optional block number to fork from")]
    pub fork_block_number: Option<BlockNumber>,
}

impl From<NewForkedEvmCliArgs> for NewForkedEvm {
    fn from(args: NewForkedEvmCliArgs) -> Self {
        NewForkedEvm {
            fork_url: args.fork_url,
            fork_block_number: args.fork_block_number,
        }
    }
}
