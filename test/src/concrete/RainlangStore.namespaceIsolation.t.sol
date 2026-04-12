// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {RainlangStore} from "../../../src/concrete/RainlangStore.sol";
import {
    LibNamespace,
    StateNamespace,
    FullyQualifiedNamespace
} from "rain.interpreter.interface/lib/ns/LibNamespace.sol";

contract RainlangStoreNamespaceIsolationTest is Test {
    using LibNamespace for StateNamespace;

    /// Data written by one msg.sender must not be readable under a different
    /// msg.sender's qualified namespace.
    function testNamespaceIsolation(
        string memory nameA,
        string memory nameB,
        uint256 nsSeed,
        bytes32 key,
        bytes32 value
    ) external {
        address addrA = makeAddr(nameA);
        address addrB = makeAddr(nameB);
        vm.assume(addrA != addrB);
        vm.assume(value != bytes32(0));

        StateNamespace ns = StateNamespace.wrap(nsSeed);
        RainlangStore store = new RainlangStore();

        // Set from address A.
        bytes32[] memory kvs = new bytes32[](2);
        kvs[0] = key;
        kvs[1] = value;
        vm.prank(addrA);
        store.set(ns, kvs);

        // Get under A's namespace returns the value.
        FullyQualifiedNamespace fqnA = ns.qualifyNamespace(addrA);
        assertEq(store.get(fqnA, key), value);

        // Get under B's namespace returns zero.
        FullyQualifiedNamespace fqnB = ns.qualifyNamespace(addrB);
        assertEq(store.get(fqnB, key), bytes32(0));
    }

    /// Same sender, different StateNamespace values — data must be isolated
    /// per namespace.
    function testNamespaceIsolationSameSender(
        address sender,
        uint256 nsSeedA,
        uint256 nsSeedB,
        bytes32 key,
        bytes32 valueA,
        bytes32 valueB
    ) external {
        vm.assume(nsSeedA != nsSeedB);
        vm.assume(valueA != valueB);

        StateNamespace nsA = StateNamespace.wrap(nsSeedA);
        StateNamespace nsB = StateNamespace.wrap(nsSeedB);
        RainlangStore store = new RainlangStore();

        bytes32[] memory kvs = new bytes32[](2);
        kvs[0] = key;

        kvs[1] = valueA;
        vm.prank(sender);
        store.set(nsA, kvs);

        kvs[1] = valueB;
        vm.prank(sender);
        store.set(nsB, kvs);

        FullyQualifiedNamespace fqnA = nsA.qualifyNamespace(sender);
        FullyQualifiedNamespace fqnB = nsB.qualifyNamespace(sender);

        assertEq(store.get(fqnA, key), valueA);
        assertEq(store.get(fqnB, key), valueB);
    }

    /// Both A and B write different values to the same key. Each must see
    /// only their own value.
    function testNamespaceIsolationBidirectional(
        string memory nameA,
        string memory nameB,
        uint256 nsSeed,
        bytes32 key,
        bytes32 valueA,
        bytes32 valueB
    ) external {
        address addrA = makeAddr(nameA);
        address addrB = makeAddr(nameB);
        vm.assume(addrA != addrB);
        vm.assume(valueA != valueB);

        StateNamespace ns = StateNamespace.wrap(nsSeed);
        RainlangStore store = new RainlangStore();

        bytes32[] memory kvs = new bytes32[](2);
        kvs[0] = key;

        kvs[1] = valueA;
        vm.prank(addrA);
        store.set(ns, kvs);

        kvs[1] = valueB;
        vm.prank(addrB);
        store.set(ns, kvs);

        FullyQualifiedNamespace fqnA = ns.qualifyNamespace(addrA);
        FullyQualifiedNamespace fqnB = ns.qualifyNamespace(addrB);

        // Each sees only their own value.
        assertEq(store.get(fqnA, key), valueA);
        assertEq(store.get(fqnB, key), valueB);
    }
}
