// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {SignedContextV2, SIGNED_CONTEXT_V2_TYPE} from "../../../src/interface/IInterpreterCallerV5.sol";

/// The EIP-712 message of a `SignedContextV2`: its typed members, without the
/// signature. ABI-encoded, this is what the struct hash cheatcode decodes.
struct SignedContextV2TypedData {
    address signer;
    bytes32[] context;
}

/// An EIP-712 domain with the four standard fields.
struct EIP712Domain {
    string name;
    string version;
    uint256 chainId;
    address verifyingContract;
}

/// EIP-712 oracle values for `SignedContextV2`, all derived by forge-std
/// cheatcodes from the type strings and EIP-712 JSON. Nothing here hashes
/// anything itself.
library LibSignedContextV2TypedData {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string constant EIP712_DOMAIN_TYPE =
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)";

    /// ABI encoding of the typed members of `signedContext`.
    function typedData(SignedContextV2 memory signedContext) internal pure returns (bytes memory) {
        return abi.encode(SignedContextV2TypedData({signer: signedContext.signer, context: signedContext.context}));
    }

    /// `hashStruct(signedContext)` from the cheatcode.
    function hashStruct(SignedContextV2 memory signedContext) internal pure returns (bytes32) {
        return vm.eip712HashStruct(SIGNED_CONTEXT_V2_TYPE, typedData(signedContext));
    }

    /// `hashStruct(domain)` from the cheatcode.
    function domainSeparator(EIP712Domain memory domain) internal pure returns (bytes32) {
        return vm.eip712HashStruct(EIP712_DOMAIN_TYPE, abi.encode(domain));
    }

    /// JSON array of the context words as 32-byte hex strings.
    function contextJson(bytes32[] memory context) internal pure returns (string memory) {
        string memory words = "[";
        for (uint256 i = 0; i < context.length; i++) {
            words = string.concat(words, i == 0 ? "" : ",", "\"", vm.toString(context[i]), "\"");
        }
        return string.concat(words, "]");
    }

    /// EIP-712 JSON (`types`, `primaryType`, `domain`, `message`) for `signer`
    /// and `context` under `domain`, as `eth_signTypedData_v4` takes it.
    function json(EIP712Domain memory domain, address signer, bytes32[] memory context)
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            "{\"types\":{\"EIP712Domain\":[{\"name\":\"name\",\"type\":\"string\"},"
            "{\"name\":\"version\",\"type\":\"string\"},{\"name\":\"chainId\",\"type\":\"uint256\"},"
            "{\"name\":\"verifyingContract\",\"type\":\"address\"}],"
            "\"SignedContextV2\":[{\"name\":\"signer\",\"type\":\"address\"},{\"name\":\"context\",\"type\":\"bytes32[]\"}]},"
            "\"primaryType\":\"SignedContextV2\",",
            "\"domain\":{\"name\":\"",
            domain.name,
            "\",\"version\":\"",
            domain.version,
            "\",\"chainId\":",
            vm.toString(domain.chainId),
            ",\"verifyingContract\":\"",
            vm.toString(domain.verifyingContract),
            "\"},",
            "\"message\":{\"signer\":\"",
            vm.toString(signer),
            "\",\"context\":",
            contextJson(context),
            "}}"
        );
    }

    /// The digest a wallet signs for `signer` and `context` under `domain`,
    /// from the cheatcode over the JSON.
    function digest(EIP712Domain memory domain, address signer, bytes32[] memory context)
        internal
        pure
        returns (bytes32)
    {
        return vm.eip712HashTypedData(json(domain, signer, context));
    }

    /// An EOA signature by `privateKey` over `digest(domain, vm.addr(privateKey), context)`.
    function sign(uint256 privateKey, EIP712Domain memory domain, bytes32[] memory context)
        internal
        pure
        returns (bytes memory)
    {
        return signFor(privateKey, domain, vm.addr(privateKey), context);
    }

    /// An EOA signature by `privateKey` over `digest(domain, signer, context)`,
    /// for a `signer` that is not necessarily `vm.addr(privateKey)`: the shape
    /// an ERC-1271 account's owner key produces for the account.
    function signFor(uint256 privateKey, EIP712Domain memory domain, address signer, bytes32[] memory context)
        internal
        pure
        returns (bytes memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest(domain, signer, context));
        return abi.encodePacked(r, s, v);
    }
}
