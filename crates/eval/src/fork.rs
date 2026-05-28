//! Re-export of the generic forking executor, which now lives in `rain-forker`.
//!
//! Kept as `rain_interpreter_eval::fork` for backwards compatibility with
//! downstream consumers. The Rain-specific `fork_eval` / `fork_parse` helpers
//! live in [`crate::eval`].
pub use rain_forker::fork::{Env, ForkId, Forker, NewForkedEvm};
pub use rain_forker::result::{ForkTypedReturn, RawCallResult};
