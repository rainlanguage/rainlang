use alloy::primitives::{Address, B256, U256, keccak256};
use rainlang_bindings::IInterpreterV4::FullyQualifiedNamespace;

/// Qualifies a state namespace by hashing it with the sender address,
/// matching the on-chain `qualifyNamespace` logic in RainlangStore.
pub fn qualify_namespace(state_namespace: B256, sender: Address) -> FullyQualifiedNamespace {
    // Combine state namespace and sender into a single 64-byte array
    let mut combined = [0u8; 64];
    combined[..32].copy_from_slice(state_namespace.as_slice());
    combined[44..].copy_from_slice(sender.as_slice());

    // Hash the combined array with Keccak256
    let qualified_namespace = keccak256(combined);

    FullyQualifiedNamespace::from(U256::from_be_bytes(qualified_namespace.0))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::str::FromStr;

    #[test]
    fn test_new() {
        let state_namespace = B256::repeat_byte(0x1);
        let sender = Address::repeat_byte(0x2);
        let namespace = qualify_namespace(state_namespace, sender);

        // Got the below from chisel
        let expected =
            B256::from_str("0x92f6b29736bf07627a27ffec88dbcb964f312685ab557770ad73f67336b9aee8")
                .unwrap()
                .as_slice()
                .to_owned();

        let mut namespace_bytes = namespace.into_underlying().as_le_slice().to_owned();
        namespace_bytes.reverse();
        assert_eq!(namespace_bytes, expected);
    }
}
