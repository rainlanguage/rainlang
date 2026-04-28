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

/// @title RainlangStoreOverwriteKeyTest
/// @notice Test that a key appearing twice in a single `kvs` array
/// results in the last value winning.
contract RainlangStoreOverwriteKeyTest is Test {
    using LibNamespace for StateNamespace;

    /// @notice A key appearing twice in a single set call must result in the
    /// last value being stored (last-write-wins).
    function testOverwriteKeyLastValueWins() external {
        RainlangStore store = new RainlangStore();
        StateNamespace namespace = StateNamespace.wrap(1);
        FullyQualifiedNamespace fqn = namespace.qualifyNamespace(address(this));

        bytes32 key = bytes32(uint256(42));
        bytes32 firstValue = bytes32(uint256(100));
        bytes32 secondValue = bytes32(uint256(200));

        bytes32[] memory kvs = new bytes32[](4);
        kvs[0] = key;
        kvs[1] = firstValue;
        kvs[2] = key;
        kvs[3] = secondValue;

        store.set(namespace, kvs);

        bytes32 stored = store.get(fqn, key);
        assertEq(stored, secondValue, "last value must win");
    }

    /// @notice A key appearing three times — the last value must persist.
    function testOverwriteKeyTriple() external {
        RainlangStore store = new RainlangStore();
        StateNamespace namespace = StateNamespace.wrap(2);
        FullyQualifiedNamespace fqn = namespace.qualifyNamespace(address(this));

        bytes32 key = bytes32(uint256(99));

        bytes32[] memory kvs = new bytes32[](6);
        kvs[0] = key;
        kvs[1] = bytes32(uint256(1));
        kvs[2] = key;
        kvs[3] = bytes32(uint256(2));
        kvs[4] = key;
        kvs[5] = bytes32(uint256(3));

        store.set(namespace, kvs);
        assertEq(store.get(fqn, key), bytes32(uint256(3)), "triple overwrite: last value must win");
    }

    /// @notice Overwriting a key among other unique keys in the same array.
    function testOverwriteKeyAmongOtherKeys() external {
        RainlangStore store = new RainlangStore();
        StateNamespace namespace = StateNamespace.wrap(3);
        FullyQualifiedNamespace fqn = namespace.qualifyNamespace(address(this));

        bytes32 dupeKey = bytes32(uint256(10));
        bytes32 uniqueKey = bytes32(uint256(20));

        bytes32[] memory kvs = new bytes32[](6);
        kvs[0] = dupeKey;
        kvs[1] = bytes32(uint256(100));
        kvs[2] = uniqueKey;
        kvs[3] = bytes32(uint256(200));
        kvs[4] = dupeKey;
        kvs[5] = bytes32(uint256(300));

        store.set(namespace, kvs);

        assertEq(store.get(fqn, dupeKey), bytes32(uint256(300)), "dupe key: last value");
        assertEq(store.get(fqn, uniqueKey), bytes32(uint256(200)), "unique key: unchanged");
    }
}
