//! CLI tool for parsing and evaluating Rainlang expressions.

use crate::commands::Parse;
use crate::execute::Execute;
use anyhow::Result;
use clap::Parser;
use commands::Eval;

mod commands;
mod execute;
mod fork;
mod output;

/// Top-level CLI command enum dispatching to `Parse` or `Eval` subcommands.
#[derive(Parser)]
pub enum Interpreter {
    /// Parse a Rainlang expression into bytecode.
    Parse(Parse),
    /// Evaluate a Rainlang expression against a forked EVM.
    Eval(Eval),
}

impl Interpreter {
    /// Dispatches to the selected subcommand's `execute` implementation.
    pub async fn execute(self) -> Result<()> {
        match self {
            Interpreter::Parse(parse) => parse.execute().await,
            Interpreter::Eval(eval) => eval.execute().await,
        }
    }
}
