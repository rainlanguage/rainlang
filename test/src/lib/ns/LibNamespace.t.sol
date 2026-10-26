// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";

import {LibNamespace, StateNamespace, FullyQualifiedNamespace} from "../../../../src/lib/ns/LibNamespace.sol";
import {LibNamespaceSlow} from "test/src/lib/ns/LibNamespaceSlow.sol";

contract LibNamespaceTest is Test {
    /// Concrete pinned-value test for qualifyNamespace.
    function testQualifyNamespaceConcrete() public pure {
        // qualifyNamespace(0, address(0)) == keccak256(abi.encode(0, 0)).
        assertEq(
            FullyQualifiedNamespace.unwrap(LibNamespace.qualifyNamespace(StateNamespace.wrap(0), address(0))),
            uint256(keccak256(abi.encode(uint256(0), uint256(0))))
        );
        // Non-zero inputs.
        assertEq(
            FullyQualifiedNamespace.unwrap(LibNamespace.qualifyNamespace(StateNamespace.wrap(1), address(0xdead))),
            uint256(keccak256(abi.encode(uint256(1), uint256(uint160(address(0xdead))))))
        );
    }

    function testQualifyNamespaceReferenceImplementation(StateNamespace stateNamespace, address sender) public pure {
        assertEq(
            FullyQualifiedNamespace.unwrap(LibNamespace.qualifyNamespace(stateNamespace, sender)),
            FullyQualifiedNamespace.unwrap(LibNamespaceSlow.qualifyNamespaceSlow(stateNamespace, sender))
        );
    }

    function testQualifyNamespaceGas0(StateNamespace stateNamespace, address sender) public pure {
        LibNamespace.qualifyNamespace(stateNamespace, sender);
    }

    function testQualifyNamespaceGasSlow0(StateNamespace stateNamespace, address sender) public pure {
        LibNamespaceSlow.qualifyNamespaceSlow(stateNamespace, sender);
    }
}
