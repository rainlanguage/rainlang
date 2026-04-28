//! DISPaiR (Deployer/Interpreter/Store/Parser) address tuple.

use alloy::primitives::Address;

/// Deployer/Interpreter/Store/Parser address tuple.
///
/// Groups the four contract addresses that together form a complete
/// Rain interpreter deployment.
#[derive(Debug, Clone, Default)]
pub struct DISPaiR {
    pub deployer: Address,
    pub interpreter: Address,
    pub store: Address,
    pub parser: Address,
}

impl DISPaiR {
    /// Creates a new `DISPaiR` from the four component addresses.
    pub fn new(deployer: Address, interpreter: Address, store: Address, parser: Address) -> Self {
        DISPaiR {
            deployer,
            interpreter,
            store,
            parser,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new() {
        let deployer = Address::repeat_byte(0x1);
        let interpreter = Address::repeat_byte(0x2);
        let store = Address::repeat_byte(0x3);
        let parser = Address::repeat_byte(0x4);

        let dispair = DISPaiR::new(deployer, interpreter, store, parser);

        assert_eq!(dispair.deployer, deployer);
        assert_eq!(dispair.interpreter, interpreter);
        assert_eq!(dispair.store, store);
        assert_eq!(dispair.parser, parser);
    }
}
