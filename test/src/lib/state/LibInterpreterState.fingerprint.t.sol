// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {InterpreterState} from "../../../../src/lib/state/LibInterpreterState.sol";
import {LibInterpreterStateFingerprint} from "test/lib/state/LibInterpreterStateFingerprint.sol";
import {Pointer} from "rain-solmem-0.1.28/src/lib/LibPointer.sol";
import {
    LibMemoryKV,
    MemoryKV,
    MemoryKVKey,
    MemoryKVVal,
    MEMORY_KV_EMPTY
} from "rain-lib-memkv-0.2.0/src/lib/LibMemoryKV.sol";
import {
    FullyQualifiedNamespace,
    IInterpreterStoreV3
} from "rainlang-interface-0.2.9/src/interface/IInterpreterStoreV3.sol";
import {StackItem} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";

contract LibInterpreterStateFingerprintTest is Test {
    using LibMemoryKV for MemoryKV;

    function emptyState() internal pure returns (InterpreterState memory) {
        return InterpreterState(
            new Pointer[](0),
            new bytes32[](0),
            0,
            MEMORY_KV_EMPTY,
            FullyQualifiedNamespace.wrap(0),
            IInterpreterStoreV3(address(0)),
            new bytes32[][](0),
            hex"00",
            hex""
        );
    }

    /// Two identically constructed states must produce the same fingerprint.
    function testFingerprintDeterministic() external pure {
        InterpreterState memory a = InterpreterState(
            new Pointer[](0),
            new bytes32[](0),
            0,
            MemoryKV.wrap(0),
            FullyQualifiedNamespace.wrap(0),
            IInterpreterStoreV3(address(0)),
            new bytes32[][](0),
            hex"00",
            hex""
        );
        InterpreterState memory b = InterpreterState(
            new Pointer[](0),
            new bytes32[](0),
            0,
            MemoryKV.wrap(0),
            FullyQualifiedNamespace.wrap(0),
            IInterpreterStoreV3(address(0)),
            new bytes32[][](0),
            hex"00",
            hex""
        );
        assertEq(LibInterpreterStateFingerprint.fingerprint(a), LibInterpreterStateFingerprint.fingerprint(b));
    }

    /// Changing sourceIndex must change the fingerprint.
    function testFingerprintChangesWithSourceIndex(uint256 indexA, uint256 indexB) external pure {
        vm.assume(indexA != indexB);
        InterpreterState memory a = InterpreterState(
            new Pointer[](0),
            new bytes32[](0),
            indexA,
            MemoryKV.wrap(0),
            FullyQualifiedNamespace.wrap(0),
            IInterpreterStoreV3(address(0)),
            new bytes32[][](0),
            hex"00",
            hex""
        );
        InterpreterState memory b = InterpreterState(
            new Pointer[](0),
            new bytes32[](0),
            indexB,
            MemoryKV.wrap(0),
            FullyQualifiedNamespace.wrap(0),
            IInterpreterStoreV3(address(0)),
            new bytes32[][](0),
            hex"00",
            hex""
        );
        assertTrue(LibInterpreterStateFingerprint.fingerprint(a) != LibInterpreterStateFingerprint.fingerprint(b));
    }

    /// An insert into a stateKV that already holds a pair must change the
    /// fingerprint.
    function testFingerprintChangesOnInsertIntoNonEmptyStateKV(
        bytes32 keyA,
        bytes32 valueA,
        bytes32 keyB,
        bytes32 valueB
    ) external pure {
        vm.assume(keyA != keyB);
        InterpreterState memory state = emptyState();
        state.stateKV = state.stateKV.set(MemoryKVKey.wrap(keyA), MemoryKVVal.wrap(valueA));
        bytes32 fingerprintBefore = LibInterpreterStateFingerprint.fingerprint(state);
        state.stateKV = state.stateKV.set(MemoryKVKey.wrap(keyB), MemoryKVVal.wrap(valueB));
        assertTrue(LibInterpreterStateFingerprint.fingerprint(state) != fingerprintBefore);
    }

    /// Setting a new value for a key already in stateKV must change the
    /// fingerprint.
    function testFingerprintChangesOnStateKVUpdate(bytes32 key, bytes32 valueA, bytes32 valueB) external pure {
        vm.assume(valueA != valueB);
        InterpreterState memory state = emptyState();
        state.stateKV = state.stateKV.set(MemoryKVKey.wrap(key), MemoryKVVal.wrap(valueA));
        bytes32 fingerprintBefore = LibInterpreterStateFingerprint.fingerprint(state);
        state.stateKV = state.stateKV.set(MemoryKVKey.wrap(key), MemoryKVVal.wrap(valueB));
        assertTrue(LibInterpreterStateFingerprint.fingerprint(state) != fingerprintBefore);
    }

    /// Two separate stores holding the same pairs, inserted in opposite orders,
    /// fingerprint the same although their handles and export orders differ.
    function testFingerprintSameForSamePairsInSeparateStores(bytes32 seed) external pure {
        uint256 pairs = 32;
        InterpreterState memory forward = emptyState();
        InterpreterState memory backward = emptyState();
        for (uint256 i = 0; i < pairs; i++) {
            uint256 j = pairs - 1 - i;
            forward.stateKV =
                forward.stateKV.set(MemoryKVKey.wrap(keccak256(abi.encode(seed, i))), MemoryKVVal.wrap(bytes32(i)));
            backward.stateKV =
                backward.stateKV.set(MemoryKVKey.wrap(keccak256(abi.encode(seed, j))), MemoryKVVal.wrap(bytes32(j)));
        }
        assertTrue(
            keccak256(abi.encode(forward.stateKV.toBytes32Array()))
                != keccak256(abi.encode(backward.stateKV.toBytes32Array())),
            "export orders differ"
        );
        assertEq(
            LibInterpreterStateFingerprint.fingerprint(forward), LibInterpreterStateFingerprint.fingerprint(backward)
        );
    }

    /// Fingerprinting leaves `state.stateKV` holding the handle it had.
    function testFingerprintLeavesStateKVHandle(bytes32 key, bytes32 value) external pure {
        InterpreterState memory state = emptyState();
        state.stateKV = state.stateKV.set(MemoryKVKey.wrap(key), MemoryKVVal.wrap(value));
        MemoryKV handle = state.stateKV;
        LibInterpreterStateFingerprint.fingerprint(state);
        assertEq(MemoryKV.unwrap(state.stateKV), MemoryKV.unwrap(handle));
    }

    /// Stores holding the same value under different keys fingerprint
    /// differently.
    function testFingerprintDiffersForDifferentKeys(bytes32 keyA, bytes32 keyB, bytes32 value) external pure {
        vm.assume(keyA != keyB);
        InterpreterState memory a = emptyState();
        InterpreterState memory b = emptyState();
        a.stateKV = a.stateKV.set(MemoryKVKey.wrap(keyA), MemoryKVVal.wrap(value));
        b.stateKV = b.stateKV.set(MemoryKVKey.wrap(keyB), MemoryKVVal.wrap(value));
        assertTrue(LibInterpreterStateFingerprint.fingerprint(a) != LibInterpreterStateFingerprint.fingerprint(b));
    }
}
