//! Evaluation runtime for Rainlang expressions using forked EVM contexts.
//!
//! The generic forking executor (`Forker`, `RawCallResult`, `ForkCallError`, …)
//! comes from the [`rain_forker`] crate and is re-exported here for backwards
//! compatibility; this crate adds the Rain-specific evaluation, parsing, and
//! trace decoding on top. Forking is native-only, so those modules are gated.

#[cfg(not(target_family = "wasm"))]
pub mod error;
#[cfg(not(target_family = "wasm"))]
pub mod eval;
#[cfg(not(target_family = "wasm"))]
pub mod fork;
pub mod namespace;
pub mod trace;
