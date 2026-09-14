// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {TestRainlangStore} from "test/concrete/TestRainlangStore.sol";
import {StateNamespace} from "rainlang-interface-0.2.9/src/lib/ns/LibNamespace.sol";

/// @title RainlangStoreSetEmptyArrayTest
/// @notice Test that `set()` with an empty (zero-length) `kvs` array
/// succeeds without reverting.
contract RainlangStoreSetEmptyArrayTest is Test {
    /// @notice set() with a zero-length kvs array must not revert.
    function testSetEmptyArray() external {
        TestRainlangStore store = new TestRainlangStore();
        StateNamespace namespace = StateNamespace.wrap(1);

        bytes32[] memory kvs = new bytes32[](0);
        store.set(namespace, kvs);
    }

    /// @notice set() with a zero-length kvs array should not emit any Set
    /// events.
    function testSetEmptyArrayNoEvents() external {
        TestRainlangStore store = new TestRainlangStore();
        StateNamespace namespace = StateNamespace.wrap(1);

        bytes32[] memory kvs = new bytes32[](0);

        vm.recordLogs();
        store.set(namespace, kvs);

        assertEq(vm.getRecordedLogs().length, 0, "empty set should emit no events");
    }

    /// @notice Fuzz variant: set() with empty array and any namespace must not
    /// revert.
    function testSetEmptyArrayFuzz(StateNamespace namespace) external {
        TestRainlangStore store = new TestRainlangStore();
        bytes32[] memory kvs = new bytes32[](0);
        store.set(namespace, kvs);
    }
}
