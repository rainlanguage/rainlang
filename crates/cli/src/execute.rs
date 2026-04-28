use anyhow::Result;

/// Trait for CLI subcommands that can be executed asynchronously.
pub trait Execute {
    /// Runs the subcommand, returning an error on failure.
    async fn execute(&self) -> Result<()>;
}
