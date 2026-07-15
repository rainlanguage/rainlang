// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {BaseRainlangExtern} from "../../../src/abstract/BaseRainlangExtern.sol";
import {ExternDispatchV2} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterExternV4.sol";
import {ExternOpcodeOutOfRange} from "../../../src/error/ErrExtern.sol";
import {TwoOpExtern} from "./TwoOpExtern.sol";

/// @title BaseRainlangExternIntegrityOpcodeRangeTest
/// @notice Tests that externIntegrity reverts for out-of-range opcodes.
contract BaseRainlangExternIntegrityOpcodeRangeTest is Test {
    /// Any opcode >= fsCount must revert with ExternOpcodeOutOfRange.
    function testExternIntegrityRevertsOpcodeOutOfRange(uint16 opcode, uint16 operand) external {
        // TwoOpExtern has 2 pointers, so valid opcodes are 0 and 1.
        vm.assume(opcode >= 2);
        TwoOpExtern ext = new TwoOpExtern();

        // Encode opcode into bits 16-31 and operand into bits 0-15 of the
        // dispatch bytes32.
        bytes32 dispatch = bytes32(uint256(opcode)) << 0x10 | bytes32(uint256(operand));

        vm.expectRevert(abi.encodeWithSelector(ExternOpcodeOutOfRange.selector, uint256(opcode), 2));
        ext.externIntegrity(ExternDispatchV2.wrap(dispatch), 0, 0);
    }

    /// Boundary: opcode == fsCount - 1 must NOT revert with ExternOpcodeOutOfRange.
    /// TwoOpExtern has fsCount == 2, so opcode 1 is valid.
    function testExternIntegrityBoundaryHighestValidOpcode(uint16 operand) external {
        TwoOpExtern ext = new TwoOpExtern();

        // opcode 1 is fsCount - 1
        bytes32 dispatch = bytes32(uint256(1)) << 0x10 | bytes32(uint256(operand));

        // Dummy function pointers will cause some other revert, but NOT
        // ExternOpcodeOutOfRange. That's what we're testing.
        try ext.externIntegrity(ExternDispatchV2.wrap(dispatch), 0, 0) {}
        catch (bytes memory reason) {
            assertTrue(
                keccak256(reason) != keccak256(abi.encodeWithSelector(ExternOpcodeOutOfRange.selector, uint256(1), 2)),
                "should not revert with ExternOpcodeOutOfRange for valid opcode"
            );
        }
    }
}
