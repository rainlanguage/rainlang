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

/// @title RainlangStoreGetUninitializedTest
/// @notice Test that `get()` returns `bytes32(0)` for a key that has
/// never been set.
contract RainlangStoreGetUninitializedTest is Test {
    using LibNamespace for StateNamespace;

    /// @notice get() on a key that was never set must return bytes32(0).
    function testGetUninitializedKey() external {
        RainlangStore store = new RainlangStore();
        StateNamespace namespace = StateNamespace.wrap(1);
        FullyQualifiedNamespace fqn = namespace.qualifyNamespace(address(this));

        bytes32 key = bytes32(uint256(0xdeadbeef));
        bytes32 value = store.get(fqn, key);
        assertEq(value, bytes32(0), "uninitialized key must return 0");
    }

    /// @notice Fuzz: get() on any never-set namespace+key must return 0.
    function testGetUninitializedKeyFuzz(StateNamespace namespace, bytes32 key) external {
        RainlangStore store = new RainlangStore();
        FullyQualifiedNamespace fqn = namespace.qualifyNamespace(address(this));

        bytes32 value = store.get(fqn, key);
        assertEq(value, bytes32(0), "uninitialized key must return 0 (fuzz)");
    }

    /// @notice After setting a different key, the original uninitialized key
    /// must still return 0.
    function testGetUninitializedAfterSetDifferentKey() external {
        RainlangStore store = new RainlangStore();
        StateNamespace namespace = StateNamespace.wrap(1);
        FullyQualifiedNamespace fqn = namespace.qualifyNamespace(address(this));

        bytes32 setKey = bytes32(uint256(1));
        bytes32 setValue = bytes32(uint256(999));
        bytes32[] memory kvs = new bytes32[](2);
        kvs[0] = setKey;
        kvs[1] = setValue;
        store.set(namespace, kvs);

        bytes32 otherKey = bytes32(uint256(2));
        bytes32 value = store.get(fqn, otherKey);
        assertEq(value, bytes32(0), "different key must still return 0");
    }
}
