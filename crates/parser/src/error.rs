use alloy_ethers_typecast::{ReadContractParametersBuilderError, ReadableClientError};
use thiserror::Error;

/// Errors that can occur during Rust-side parsing operations.
#[derive(Error, Debug)]
pub enum ParserError {
    #[error(transparent)]
    ReadableClientError(#[from] ReadableClientError),
    #[error(transparent)]
    ReadContractParametersBuilderError(#[from] ReadContractParametersBuilderError),
}
