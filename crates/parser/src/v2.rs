use crate::error::ParserError;
use alloy::primitives::Address;
use alloy_ethers_typecast::{ReadContractParametersBuilder, ReadableClient};
use rainlang_bindings::IParserPragmaV1::*;
use rainlang_bindings::IParserV2::*;
use rainlang_dispair::DISPaiR;

/// Trait for interacting with the on-chain Rainlang parser contract.
#[cfg(not(target_family = "wasm"))]
pub trait Parser2 {
    /// Call Parser contract to parse the provided rainlang text.
    fn parse_text(
        &self,
        text: &str,
        client: ReadableClient,
    ) -> impl std::future::Future<Output = Result<parse2Return, ParserError>> + Send
    where
        Self: Sync,
    {
        self.parse(text.as_bytes().to_vec(), client)
    }

    /// Call Parser contract to parse the provided data
    /// The provided data must contain valid UTF-8 encoding of valid rainlang text.
    fn parse(
        &self,
        data: Vec<u8>,
        client: ReadableClient,
    ) -> impl std::future::Future<Output = Result<parse2Return, ParserError>> + Send;

    /// Call Parser contract to parse the provided rainlang text and provide the pragma.
    /// The provided rainlang text must be valid UTF-8 encoding of valid rainlang text.
    fn parse_pragma(
        &self,
        data: Vec<u8>,
        client: ReadableClient,
    ) -> impl std::future::Future<Output = Result<parsePragma1Return, ParserError>> + Send;

    /// Call Parser contract to parse the provided rainlang text and return the pragma addresses.
    fn parse_pragma_text(
        &self,
        text: &str,
        client: ReadableClient,
    ) -> impl std::future::Future<Output = Result<Vec<Address>, ParserError>> + Send
    where
        Self: Sync,
    {
        async {
            let res = self.parse_pragma(text.as_bytes().to_vec(), client).await?;
            Ok(res._0.usingWordsFrom)
        }
    }
}

/// Trait for interacting with the on-chain Rainlang parser contract.
#[cfg(target_family = "wasm")]
pub trait Parser2 {
    /// Call Parser contract to parse the provided rainlang text.
    fn parse_text(
        &self,
        text: &str,
        client: ReadableClient,
    ) -> impl std::future::Future<Output = Result<parse2Return, ParserError>>
    where
        Self: Sync,
    {
        self.parse(text.as_bytes().to_vec(), client)
    }

    /// Call Parser contract to parse the provided data
    /// The provided data must contain valid UTF-8 encoding of valid rainlang text.
    fn parse(
        &self,
        data: Vec<u8>,
        client: ReadableClient,
    ) -> impl std::future::Future<Output = Result<parse2Return, ParserError>>;

    /// Call Parser contract to parse the provided rainlang text and provide the pragma.
    /// The provided rainlang text must be valid UTF-8 encoding of valid rainlang text.
    fn parse_pragma(
        &self,
        data: Vec<u8>,
        client: ReadableClient,
    ) -> impl std::future::Future<Output = Result<parsePragma1Return, ParserError>>;

    /// Call Parser contract to parse the provided rainlang text and return the pragma addresses.
    fn parse_pragma_text(
        &self,
        text: &str,
        client: ReadableClient,
    ) -> impl std::future::Future<Output = Result<Vec<Address>, ParserError>>
    where
        Self: Sync,
    {
        async {
            let res = self.parse_pragma(text.as_bytes().to_vec(), client).await?;
            Ok(res._0.usingWordsFrom)
        }
    }
}

/// Client-side wrapper around a deployer address that implements [`Parser2`]
/// by making read calls to the on-chain deployer contract (which implements
/// `IParserV2`).
///
/// The deployer address is typically discovered from Rainlang.
#[derive(Clone, Default)]
pub struct ParserV2 {
    /// The address of the expression deployer (implements `IParserV2`).
    pub deployer_address: Address,
}

impl From<DISPaiR> for ParserV2 {
    fn from(val: DISPaiR) -> Self {
        Self {
            deployer_address: val.deployer,
        }
    }
}

impl From<Address> for ParserV2 {
    fn from(val: Address) -> Self {
        Self {
            deployer_address: val,
        }
    }
}

impl ParserV2 {
    /// Creates a new `ParserV2` for the given deployer address.
    pub fn new(deployer_address: Address) -> Self {
        Self { deployer_address }
    }
}

impl Parser2 for ParserV2 {
    async fn parse(
        &self,
        data: Vec<u8>,
        client: ReadableClient,
    ) -> Result<parse2Return, ParserError> {
        let bytecode = client
            .read(
                ReadContractParametersBuilder::default()
                    .address(self.deployer_address)
                    .call(parse2Call { data: data.into() })
                    .build()
                    .map_err(ParserError::ReadContractParametersBuilderError)?,
            )
            .await
            .map_err(ParserError::ReadableClientError)?;

        Ok(parse2Return { bytecode })
    }

    async fn parse_pragma(
        &self,
        data: Vec<u8>,
        client: ReadableClient,
    ) -> Result<parsePragma1Return, ParserError> {
        let pragma = client
            .read(
                ReadContractParametersBuilder::default()
                    .address(self.deployer_address)
                    .call(parsePragma1Call { data: data.into() })
                    .build()
                    .map_err(ParserError::ReadContractParametersBuilderError)?,
            )
            .await
            .map_err(ParserError::ReadableClientError)?;

        Ok(parsePragma1Return { _0: pragma })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::{hex, primitives::Address, providers::mock::Asserter};

    #[tokio::test]
    async fn test_from_dispair() {
        let deployer_address = Address::repeat_byte(0x4);

        let dispair = DISPaiR {
            deployer: deployer_address,
            interpreter: Address::repeat_byte(0x2),
            store: Address::repeat_byte(0x3),
            parser: Address::repeat_byte(0x1),
        };

        let parser: ParserV2 = dispair.clone().into();

        assert_eq!(parser.deployer_address, dispair.deployer);
        assert_eq!(parser.deployer_address, deployer_address);
    }

    #[tokio::test]
    async fn test_parse() {
        let asserter = Asserter::new();
        asserter.push_success(
            &[
                "0x0000000000000000000000000000000000000000000000000000000000000020", // offset to start of bytecode
                "0000000000000000000000000000000000000000000000000000000000000002", // length of bytecode
                "1234000000000000000000000000000000000000000000000000000000000000", // bytecode
            ]
            .concat(),
        );

        let client = ReadableClient::new_mocked(asserter);
        let parser = ParserV2 {
            deployer_address: Address::repeat_byte(0x1),
        };

        let result = parser.parse_text("my rainlang", client).await.unwrap();

        assert_eq!(**result.bytecode, hex!("1234"));
    }

    #[tokio::test]
    async fn test_parse_text() {
        let rainlang = "my rainlang";

        let asserter = Asserter::new();
        asserter.push_success(
            &[
                "0x0000000000000000000000000000000000000000000000000000000000000020", // length of bytecode
                "000000000000000000000000000000000000000000000000000000000000000b", // offset to start of bytecode
                "6d79207261696e6c616e67000000000000000000000000000000000000000000", // bytecode
            ]
            .concat(),
        );

        let client = ReadableClient::new_mocked(asserter);
        let parser = ParserV2 {
            deployer_address: Address::repeat_byte(0x1),
        };

        let result = parser.parse_text(rainlang, client).await.unwrap();

        assert_eq!(**result.bytecode, hex!("6d79207261696e6c616e67"));
    }

    #[tokio::test]
    async fn test_parse_pragma_text() {
        let rainlang = "my rainlang"; // we aren't actually using the onchian parser so this could be anything

        let pragma1 = Address::repeat_byte(0x11);
        let pragma2 = Address::repeat_byte(0x22);

        let asserter = Asserter::new();
        asserter.push_success(
            &[
                "0000000000000000000000000000000000000000000000000000000000000020", // offset
                "0000000000000000000000000000000000000000000000000000000000000020", // offset
                "0000000000000000000000000000000000000000000000000000000000000002", // array length
                "0000000000000000000000001111111111111111111111111111111111111111",
                "0000000000000000000000002222222222222222222222222222222222222222", // array of addresses
            ]
            .concat(),
        );

        let client = ReadableClient::new_mocked(asserter);
        let parser = ParserV2 {
            deployer_address: Address::repeat_byte(0x1),
        };

        let result = parser.parse_pragma_text(rainlang, client).await.unwrap();

        assert_eq!(result[0], pragma1);
        assert_eq!(result[1], pragma2);
    }
}
