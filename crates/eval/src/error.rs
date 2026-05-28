//! Re-export of the forking error types, which now live in `rain-forker`.
//!
//! Kept as `rain_interpreter_eval::error` for backwards compatibility with
//! downstream consumers.
pub use rain_forker::error::{ForkCallError, ReplayTransactionError};
