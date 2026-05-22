use alloy::sol_types;
use alloy::transports::TransportError;
use thiserror::Error;

/// Errors that can occur during Rust-side parsing operations.
#[derive(Error, Debug)]
pub enum ParserError {
    #[error(transparent)]
    Transport(#[from] TransportError),
    #[error(transparent)]
    AbiDecode(#[from] sol_types::Error),
}
