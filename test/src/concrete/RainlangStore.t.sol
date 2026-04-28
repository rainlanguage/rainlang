// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {LibBytes32Array} from "rain.solmem/lib/LibBytes32Array.sol";
import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {LibMemoryKV, MemoryKV, MemoryKVVal, MemoryKVKey} from "rain.lib.memkv/lib/LibMemoryKV.sol";
import {LibNamespace, StateNamespace} from "rain.interpreter.interface/lib/ns/LibNamespace.sol";
import {RainlangStore} from "../../../src/concrete/RainlangStore.sol";
import {OddSetLength} from "../../../src/error/ErrStore.sol";

/// @title RainlangStoreTest
/// @notice Test suite for RainlangStore.
contract RainlangStoreTest is Test {
    using LibNamespace for StateNamespace;
    using LibMemoryKV for MemoryKV;
    using Address for address;

    /// Ensure the store gives a decent error message when an odd number of
    /// arguments is passed to `set`.
    /// forge-config: default.fuzz.runs = 100
    function testRainlangStoreSetOddLength(StateNamespace namespace, bytes32[] memory kvs) external {
        vm.assume(kvs.length % 2 != 0);

        RainlangStore store = new RainlangStore();
        vm.expectRevert(abi.encodeWithSelector(OddSetLength.selector, kvs.length));
        store.set(namespace, kvs);
    }

    /// Store should set and get values correctly.
    /// This test assumes no dupes.
    /// forge-config: default.fuzz.runs = 100
    function testRainlangStoreSetGetNoDupesSingle(StateNamespace namespace, bytes32[] memory kvs) external {
        // Truncate to even length.
        uint256 newLength = kvs.length - (kvs.length % 2);
        LibBytes32Array.truncate(kvs, newLength);
        // Remove dupe keys by simply hashing the index with each key.
        for (uint256 i = 0; i < kvs.length; i += 2) {
            kvs[i] = keccak256(abi.encodePacked(i, kvs[i]));
        }
        RainlangStore store = new RainlangStore();
        store.set(namespace, kvs);

        for (uint256 i = 0; i < kvs.length; i += 2) {
            bytes32 key = kvs[i];
            bytes32 value = kvs[i + 1];
            assertEq(store.get(namespace.qualifyNamespace(address(this)), key), value);
        }
    }

    /// @notice Represents a single `set` call to the store.
    /// @param namespace The namespace to set values in.
    /// @param kvs The key/value pairs to set.
    struct Set {
        StateNamespace namespace;
        bytes32[] kvs;
    }

    /// Store should get and set values correctly across many namespaces.j
    /// forge-config: default.fuzz.runs = 100
    function testRainlangStoreSetGetNoDupesMany(Set[] memory sets) external {
        uint256 setsLength = sets.length >= 10 ? 10 : sets.length;
        uint256[] memory refs;
        assembly ("memory-safe") {
            refs := sets
        }
        LibUint256Array.truncate(refs, setsLength);

        for (uint256 i = 0; i < sets.length; i++) {
            // Truncate to even length.
            uint256 newLength = sets[i].kvs.length - (sets[i].kvs.length % 2);
            newLength = newLength >= 10 ? 10 : newLength;
            LibBytes32Array.truncate(sets[i].kvs, newLength);
            // Remove dupe keys by simply hashing the index with each key.
            for (uint256 j = 0; j < sets[i].kvs.length; j += 2) {
                sets[i].kvs[j] = keccak256(abi.encodePacked(j, sets[i].kvs[j]));
            }
        }

        RainlangStore store = new RainlangStore();
        for (uint256 i = 0; i < sets.length; i++) {
            store.set(sets[i].namespace, sets[i].kvs);
            for (uint256 j = 0; j < sets[i].kvs.length; j += 2) {
                bytes32 key = sets[i].kvs[j];
                bytes32 value = sets[i].kvs[j + 1];
                assertEq(store.get(sets[i].namespace.qualifyNamespace(address(this)), key), value);
            }
        }
    }

    /// @notice Fixed size version of `Set` that helps the fuzzer NOT blow up all
    /// available memory. Requires some cheeky assembly to get around the
    /// fixed size to dynamic size conversion.
    /// @param namespace The namespace to set values in.
    /// @param kvs The key/value pairs to set.
    struct Set11 {
        StateNamespace namespace;
        bytes32[11] kvs;
    }
    /// Store should handle dupes correctly, where subsequent writes override
    /// previous writes to the same key (i.e. like a k/v store). The assumption
    /// is that the fuzzer will generate some dupes just randomly, so there's
    /// no special logic to make that happen.
    /// forge-config: default.fuzz.runs = 100

    function testRainlangStoreSetGetDupes(Set11[] memory sets) external {
        vm.assume(sets.length < 20);

        RainlangStore store = new RainlangStore();
        for (uint256 i = 0; i < sets.length; i++) {
            bytes32[11] memory kvsFixed = sets[i].kvs;
            bytes32[] memory kvs;
            assembly ("memory-safe") {
                kvs := kvsFixed
                mstore(kvs, 10)
            }

            store.set(sets[i].namespace, kvs);
            MemoryKV kv = MemoryKV.wrap(0);

            for (uint256 j = 0; j < kvs.length; j += 2) {
                bytes32 key = kvs[j];
                bytes32 value = kvs[j + 1];
                kv = LibMemoryKV.set(kv, MemoryKVKey.wrap(key), MemoryKVVal.wrap(value));
            }

            bytes32[] memory finalKVs = kv.toBytes32Array();
            for (uint256 j = 0; j < finalKVs.length; j += 2) {
                bytes32 key = finalKVs[j];
                bytes32 value = finalKVs[j + 1];
                assertEq(store.get(sets[i].namespace.qualifyNamespace(address(this)), key), value);
            }
        }
    }
}
