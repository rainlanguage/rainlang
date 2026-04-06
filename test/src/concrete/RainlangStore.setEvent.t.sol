// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {RainlangStore} from "../../../src/concrete/RainlangStore.sol";
import {
    LibNamespace,
    FullyQualifiedNamespace,
    StateNamespace
} from "rain.interpreter.interface/lib/ns/LibNamespace.sol";
import {IInterpreterStoreV3} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";

/// @title RainlangStoreSetEventTest
/// @notice Test that the `Set` event is emitted correctly for every
/// key-value pair stored via `set()`.
contract RainlangStoreSetEventTest is Test {
    using LibNamespace for StateNamespace;

    /// @notice A single key-value pair should emit exactly one Set event with
    /// the correct fullyQualifiedNamespace, key, and value.
    function testSetEventSinglePair() external {
        RainlangStore store = new RainlangStore();
        StateNamespace namespace = StateNamespace.wrap(42);
        FullyQualifiedNamespace fqn = namespace.qualifyNamespace(address(this));

        bytes32 key = bytes32(uint256(1));
        bytes32 value = bytes32(uint256(100));

        bytes32[] memory kvs = new bytes32[](2);
        kvs[0] = key;
        kvs[1] = value;

        vm.expectEmit(true, true, true, true);
        emit IInterpreterStoreV3.Set(fqn, key, value);
        store.set(namespace, kvs);
    }

    /// @notice Multiple key-value pairs should emit one Set event per pair.
    function testSetEventMultiplePairs() external {
        RainlangStore store = new RainlangStore();
        StateNamespace namespace = StateNamespace.wrap(7);
        FullyQualifiedNamespace fqn = namespace.qualifyNamespace(address(this));

        bytes32[] memory kvs = new bytes32[](4);
        kvs[0] = bytes32(uint256(1));
        kvs[1] = bytes32(uint256(10));
        kvs[2] = bytes32(uint256(2));
        kvs[3] = bytes32(uint256(20));

        vm.expectEmit(true, true, true, true);
        emit IInterpreterStoreV3.Set(fqn, kvs[0], kvs[1]);
        vm.expectEmit(true, true, true, true);
        emit IInterpreterStoreV3.Set(fqn, kvs[2], kvs[3]);

        store.set(namespace, kvs);
    }

    /// @notice The fullyQualifiedNamespace in the event must match what
    /// qualifyNamespace produces for the msg.sender.
    function testSetEventFQNMatchesQualifyNamespace(StateNamespace namespace, bytes32 key, bytes32 value) external {
        RainlangStore store = new RainlangStore();
        FullyQualifiedNamespace fqn = namespace.qualifyNamespace(address(this));

        bytes32[] memory kvs = new bytes32[](2);
        kvs[0] = key;
        kvs[1] = value;

        vm.expectEmit(true, true, true, true);
        emit IInterpreterStoreV3.Set(fqn, key, value);
        store.set(namespace, kvs);
    }
}
