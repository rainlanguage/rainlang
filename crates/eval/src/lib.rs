//! Evaluation runtime for Rainlang expressions using forked EVM contexts.

pub mod error;
#[cfg(not(target_family = "wasm"))]
pub mod eval;
#[cfg(not(target_family = "wasm"))]
pub mod fork;
pub mod namespace;
pub mod trace;
