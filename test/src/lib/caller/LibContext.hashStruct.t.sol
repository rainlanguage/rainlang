// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {LibContext, MessageHashUtils} from "../../../../src/lib/caller/LibContext.sol";
import {
    SignedContextV2,
    SIGNED_CONTEXT_V2_TYPE,
    SIGNED_CONTEXT_V2_TYPEHASH
} from "../../../../src/interface/IInterpreterCallerV5.sol";
import {LibSignedContextV2TypedData, EIP712Domain} from "test/lib/caller/LibSignedContextV2TypedData.sol";

contract LibContextHashStructTest is Test {
    /// The type hash literal is the keccak of the type string: as the
    /// cheatcode canonicalises the string, as `keccak256` of the string
    /// constant, and as `cast keccak` of the string reports it.
    function testSignedContextV2TypeHash() external pure {
        assertEq(SIGNED_CONTEXT_V2_TYPEHASH, vm.eip712HashType(SIGNED_CONTEXT_V2_TYPE));
        assertEq(SIGNED_CONTEXT_V2_TYPEHASH, keccak256(bytes(SIGNED_CONTEXT_V2_TYPE)));
        assertEq(SIGNED_CONTEXT_V2_TYPEHASH, 0x6ec4dff745ec96dbde88c5d41f8aa5ac13aa1664afb47b8406b44fa945a650c8);
    }

    /// `hashStruct` is the EIP-712 struct hash of the signer and context.
    function testHashStructMatchesCheatcode(SignedContextV2 memory signedContext) external pure {
        assertEq(LibContext.hashStruct(signedContext), LibSignedContextV2TypedData.hashStruct(signedContext));
    }

    /// An empty context is the EIP-712 encoding of an empty array, and the
    /// struct hash still matches.
    function testHashStructEmptyContextMatchesCheatcode(address signer, bytes memory signature) external pure {
        SignedContextV2 memory signedContext = SignedContextV2(signer, bytes32(0), new bytes32[](0), signature);
        assertEq(LibContext.hashStruct(signedContext), LibSignedContextV2TypedData.hashStruct(signedContext));
    }

    /// The signature is not part of the signed data.
    function testHashStructIgnoresSignature(
        address signer,
        bytes32[] memory context,
        bytes memory signatureA,
        bytes memory signatureB
    ) external pure {
        assertEq(
            LibContext.hashStruct(SignedContextV2(signer, bytes32(0), context, signatureA)),
            LibContext.hashStruct(SignedContextV2(signer, bytes32(0), context, signatureB))
        );
    }

    /// The domain separator is the EIP-712 domain, not a member of the type.
    function testHashStructIgnoresDomainSeparator(
        address signer,
        bytes32[] memory context,
        bytes32 domainSeparatorA,
        bytes32 domainSeparatorB
    ) external pure {
        assertEq(
            LibContext.hashStruct(SignedContextV2(signer, domainSeparatorA, context, "")),
            LibContext.hashStruct(SignedContextV2(signer, domainSeparatorB, context, ""))
        );
    }

    /// The signer is part of the signed data.
    function testHashStructBindsSigner(address signerA, address signerB, bytes32[] memory context) external pure {
        vm.assume(signerA != signerB);
        assertNotEq(
            LibContext.hashStruct(SignedContextV2(signerA, bytes32(0), context, "")),
            LibContext.hashStruct(SignedContextV2(signerB, bytes32(0), context, ""))
        );
    }

    /// Every context word is part of the signed data.
    function testHashStructBindsContextWord(address signer, bytes32[] memory context, uint256 i, bytes32 other)
        external
        pure
    {
        vm.assume(context.length > 0);
        i = bound(i, 0, context.length - 1);
        vm.assume(context[i] != other);
        bytes32 before = LibContext.hashStruct(SignedContextV2(signer, bytes32(0), context, ""));
        context[i] = other;
        assertNotEq(before, LibContext.hashStruct(SignedContextV2(signer, bytes32(0), context, "")));
    }

    /// The number of context words is part of the signed data: appending a
    /// word, including a zero word, changes the hash.
    function testHashStructBindsContextLength(address signer, bytes32[] memory context, bytes32 extra) external pure {
        bytes32 before = LibContext.hashStruct(SignedContextV2(signer, bytes32(0), context, ""));

        bytes32[] memory appended = new bytes32[](context.length + 1);
        for (uint256 i = 0; i < context.length; i++) {
            appended[i] = context[i];
        }
        appended[context.length] = extra;
        assertNotEq(before, LibContext.hashStruct(SignedContextV2(signer, bytes32(0), appended, "")));

        appended[context.length] = 0;
        assertNotEq(before, LibContext.hashStruct(SignedContextV2(signer, bytes32(0), appended, "")));
    }

    /// `hashStruct` leaves the free memory pointer and the zero slot as they
    /// were.
    function testHashStructDoesNotAllocate(SignedContextV2 memory signedContext) external pure {
        uint256 freeMemoryPointerBefore;
        bytes32 zeroSlotBefore;
        assembly ("memory-safe") {
            freeMemoryPointerBefore := mload(0x40)
            zeroSlotBefore := mload(0x60)
        }

        LibContext.hashStruct(signedContext);

        uint256 freeMemoryPointerAfter;
        bytes32 zeroSlotAfter;
        assembly ("memory-safe") {
            freeMemoryPointerAfter := mload(0x40)
            zeroSlotAfter := mload(0x60)
        }
        assertEq(freeMemoryPointerAfter, freeMemoryPointerBefore);
        assertEq(zeroSlotAfter, zeroSlotBefore);
        assertEq(zeroSlotAfter, bytes32(0));
    }

    /// The digest `buildV2` verifies, the typed data hash of the domain
    /// separator and `hashStruct`, is the digest a wallet produces from the
    /// EIP-712 JSON of the same domain and message.
    /// forge-config: default.fuzz.runs = 256
    function testTypedDataDigestMatchesCheatcode(
        address signer,
        bytes32[] memory context,
        uint64 chainId,
        address verifyingContract
    ) external pure {
        EIP712Domain memory domain = EIP712Domain("LibContextHashStructTest", "1", chainId, verifyingContract);
        bytes32 domainSeparator = LibSignedContextV2TypedData.domainSeparator(domain);
        assertEq(
            domainSeparator,
            MessageHashUtils.toDomainSeparator(bytes1(0x0f), domain.name, domain.version, chainId, verifyingContract, 0)
        );

        SignedContextV2 memory signedContext = SignedContextV2(signer, bytes32(0), context, "");
        assertEq(
            MessageHashUtils.toTypedDataHash(domainSeparator, LibContext.hashStruct(signedContext)),
            LibSignedContextV2TypedData.digest(domain, signer, context)
        );
    }
}
