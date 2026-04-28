// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibIntegrityCheck, IntegrityCheckState} from "../../../../src/lib/integrity/LibIntegrityCheck.sol";

/// @title LibIntegrityCheckNewStateTest
/// @notice Tests that newState initializes all IntegrityCheckState fields correctly.
contract LibIntegrityCheckNewStateTest is Test {
    /// Every field of the returned IntegrityCheckState must match the
    /// documented initialization: stackIndex, stackMaxIndex, and
    /// readHighwater all equal the input stackIndex; opIndex is 0;
    /// constants and bytecode are passed through.
    function testNewState(bytes memory bytecode, uint256 stackIndex, bytes32[] memory constants) external pure {
        IntegrityCheckState memory state = LibIntegrityCheck.newState(bytecode, stackIndex, constants);

        assertEq(state.stackIndex, stackIndex);
        assertEq(state.stackMaxIndex, stackIndex);
        assertEq(state.readHighwater, stackIndex);
        assertEq(state.constants.length, constants.length);
        for (uint256 i = 0; i < constants.length; i++) {
            assertEq(state.constants[i], constants[i]);
        }
        assertEq(state.opIndex, 0);
        assertEq(keccak256(state.bytecode), keccak256(bytecode));
    }
}
