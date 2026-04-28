// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibIntegrityCheck, IntegrityCheckState} from "../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {
    OpcodeOutOfRange,
    StackUnderflow,
    StackUnderflowHighwater,
    StackAllocationMismatch,
    StackOutputsMismatch
} from "../../../../src/error/ErrIntegrity.sol";
import {BadOpInputsLength, BadOpOutputsLength} from "rain.interpreter.interface/error/ErrIntegrity.sol";
import {INTEGRITY_FUNCTION_POINTERS} from "../../../../src/generated/RainlangExpressionDeployer.pointers.sol";
import {ALL_STANDARD_OPS_LENGTH} from "../../../../src/lib/op/LibAllStandardOps.sol";
import {LibConvert} from "rain.lib.typecast/LibConvert.sol";
import {OperandV2} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

/// @dev Contract whose integrity function pointers are valid for its own
/// bytecode. Has a single opcode (index 0) that always returns (1, 1).
contract IntegritySingleOp {
    function oneInputOneOutput(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        return (1, 1);
    }

    function buildIntegrityPointers() external pure returns (bytes memory) {
        unchecked {
            function(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) lengthPointer;
            uint256 length = 1;
            assembly ("memory-safe") {
                lengthPointer := length
            }
            function(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256)[2] memory
                pointersFixed = [lengthPointer, oneInputOneOutput];
            uint256[] memory pointersDynamic;
            assembly ("memory-safe") {
                pointersDynamic := pointersFixed
            }
            return LibConvert.unsafeTo16BitBytes(pointersDynamic);
        }
    }

    function runIntegrityCheck(bytes memory fPointers, bytes memory bytecode, bytes32[] memory constants)
        external
        view
        returns (bytes memory)
    {
        return LibIntegrityCheck.integrityCheck2(fPointers, bytecode, constants);
    }
}

/// @dev Contract with 2 opcodes for testing StackUnderflowHighwater.
/// Opcode 0: 0 inputs, 2 outputs (advances highwater).
/// Opcode 1: 2 inputs, 1 output (drops stack below highwater).
contract IntegrityHighwater {
    function zeroInputTwoOutput(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        return (0, 2);
    }

    function twoInputOneOutput(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        return (2, 1);
    }

    function buildIntegrityPointers() external pure returns (bytes memory) {
        unchecked {
            function(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) lengthPointer;
            uint256 length = 2;
            assembly ("memory-safe") {
                lengthPointer := length
            }
            function(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256)[3] memory
                pointersFixed = [lengthPointer, zeroInputTwoOutput, twoInputOneOutput];
            uint256[] memory pointersDynamic;
            assembly ("memory-safe") {
                pointersDynamic := pointersFixed
            }
            return LibConvert.unsafeTo16BitBytes(pointersDynamic);
        }
    }

    function runIntegrityCheck(bytes memory fPointers, bytes memory bytecode, bytes32[] memory constants)
        external
        view
        returns (bytes memory)
    {
        return LibIntegrityCheck.integrityCheck2(fPointers, bytecode, constants);
    }
}

/// @title LibIntegrityCheckTest
/// @notice Tests for LibIntegrityCheck.
contract LibIntegrityCheckTest is Test {
    /// Wrap integrityCheck2 in an external call so vm.expectRevert works.
    function integrityCheck2External(bytes memory fPointers, bytes memory bytecode, bytes32[] memory constants)
        external
        view
        returns (bytes memory)
    {
        return LibIntegrityCheck.integrityCheck2(fPointers, bytecode, constants);
    }

    /// Build minimal valid-structure bytecode containing a single source with
    /// a single opcode at the given opcode index. The ioByte declares 0 inputs
    /// and 1 output, and the stack allocation is 1.
    function buildSingleOpBytecode(uint256 opcodeIndex) internal pure returns (bytes memory) {
        // Bytecode layout:
        // [0]    sourceCount = 1
        // [1-2]  relative offset for source 0 = 0x0000
        // [3]    opsCount = 1
        // [4]    stackAllocation = 1
        // [5]    inputs = 0
        // [6]    outputs = 1
        // [7]    opcodeIndex
        // [8]    ioByte = 0x10 (0 inputs, 1 output)
        // [9-10] operand = 0x0000
        return abi.encodePacked(
            uint8(1), // sourceCount
            uint16(0), // relative offset source 0
            uint8(1), // opsCount
            uint8(1), // stackAllocation
            uint8(0), // inputs
            uint8(1), // outputs
            // Truncation is safe because callers bound opcodeIndex to uint8 range.
            // forge-lint: disable-next-line(unsafe-typecast)
            uint8(opcodeIndex), // opcode index
            uint8(0x10), // ioByte: 0 inputs, 1 output
            uint16(0) // operand
        );
    }

    /// An opcode index >= ALL_STANDARD_OPS_LENGTH must revert with
    /// OpcodeOutOfRange during the integrity check.
    function testOpcodeOutOfRange(uint256 opcodeIndex) external {
        opcodeIndex = bound(opcodeIndex, ALL_STANDARD_OPS_LENGTH, type(uint8).max);
        bytes memory bytecode = buildSingleOpBytecode(opcodeIndex);
        bytes32[] memory constants = new bytes32[](0);

        vm.expectRevert(abi.encodeWithSelector(OpcodeOutOfRange.selector, 0, opcodeIndex, ALL_STANDARD_OPS_LENGTH));
        this.integrityCheck2External(INTEGRITY_FUNCTION_POINTERS, bytecode, constants);
    }

    /// An opcode index just below the boundary must NOT revert with
    /// OpcodeOutOfRange. It may revert for other reasons (e.g., the opcode's
    /// own integrity function may reject the operand), but not OpcodeOutOfRange.
    function testOpcodeInRange() external view {
        // Opcode 0 is "stack", which with operand 0 reads stack index 0.
        // With 0 inputs declared, stack index 0 is out of bounds, so it will
        // revert — but NOT with OpcodeOutOfRange.
        uint256 maxValidIndex = ALL_STANDARD_OPS_LENGTH - 1;
        bytes memory bytecode = buildSingleOpBytecode(maxValidIndex);
        bytes32[] memory constants = new bytes32[](0);

        // We just verify the revert is NOT OpcodeOutOfRange.
        // The actual revert depends on what opcode maxValidIndex is, but
        // it should never be OpcodeOutOfRange.
        try this.integrityCheck2External(INTEGRITY_FUNCTION_POINTERS, bytecode, constants) {
        // If it doesn't revert, that's fine too — the opcode is in range.
        }
        catch (bytes memory reason) {
            // Ensure the revert is NOT OpcodeOutOfRange.
            // Truncation is guarded by the reason.length < 4 check.
            // forge-lint: disable-next-line(unsafe-typecast)
            bytes4 errorSig = reason.length >= 4 ? bytes4(reason) : bytes4(0);
            assertTrue(
                errorSig != OpcodeOutOfRange.selector, "should not revert with OpcodeOutOfRange for in-range opcode"
            );
        }
    }

    /// StackUnderflow: opcode 0 needs 1 input but the stack is empty.
    /// Uses IntegritySingleOp which has its own valid function pointers.
    function testStackUnderflow() external {
        IntegritySingleOp helper = new IntegritySingleOp();
        bytes memory fPointers = helper.buildIntegrityPointers();

        // Single source, 0 source inputs, 1 output.
        // Opcode 0 with ioByte 0x11 (1 input, 1 output).
        bytes memory bytecode = abi.encodePacked(
            uint8(1), // sourceCount
            uint16(0), // relative offset source 0
            uint8(1), // opsCount
            uint8(1), // stackAllocation
            uint8(0), // source inputs = 0
            uint8(1), // source outputs = 1
            uint8(0), // opcode index 0 (oneInputOneOutput)
            uint8(0x11), // ioByte: 1 input, 1 output
            uint16(0) // operand
        );
        bytes32[] memory constants = new bytes32[](0);

        vm.expectRevert(abi.encodeWithSelector(StackUnderflow.selector, 0, 0, 1));
        helper.runIntegrityCheck(fPointers, bytecode, constants);
    }

    /// StackUnderflowHighwater: opcode 0 produces 2 outputs (advancing the
    /// highwater to 2), then opcode 1 consumes 2 inputs (dropping the stack
    /// to 0, which is below the highwater of 2).
    function testStackUnderflowHighwater() external {
        IntegrityHighwater helper = new IntegrityHighwater();
        bytes memory fPointers = helper.buildIntegrityPointers();

        // 2 opcodes in a single source, 0 source inputs, 1 output.
        // Op 0: opcode 0, ioByte 0x20 (0 inputs, 2 outputs)
        // Op 1: opcode 1, ioByte 0x12 (2 inputs, 1 output)
        bytes memory bytecode = abi.encodePacked(
            uint8(1), // sourceCount
            uint16(0), // relative offset source 0
            uint8(2), // opsCount = 2
            uint8(2), // stackAllocation
            uint8(0), // source inputs = 0
            uint8(1), // source outputs = 1
            uint8(0), // opcode 0 (zeroInputTwoOutput)
            uint8(0x20), // ioByte: 0 inputs, 2 outputs
            uint16(0), // operand
            uint8(1), // opcode 1 (twoInputOneOutput)
            uint8(0x12), // ioByte: 2 inputs, 1 output
            uint16(0) // operand
        );
        bytes32[] memory constants = new bytes32[](0);

        vm.expectRevert(abi.encodeWithSelector(StackUnderflowHighwater.selector, 1, 0, 2));
        helper.runIntegrityCheck(fPointers, bytecode, constants);
    }

    /// StackAllocationMismatch: opcode 0 produces 2 outputs from 0 inputs,
    /// so stackMaxIndex reaches 2. Declaring stackAllocation = 3 triggers
    /// StackAllocationMismatch(2, 3).
    function testStackAllocationMismatch() external {
        IntegrityHighwater twoOp = new IntegrityHighwater();
        bytes memory fPointers = twoOp.buildIntegrityPointers();

        bytes memory bytecode = abi.encodePacked(
            uint8(1), // sourceCount
            uint16(0), // relative offset source 0
            uint8(1), // opsCount
            uint8(3), // stackAllocation = 3 (WRONG — actual max is 2)
            uint8(0), // source inputs = 0
            uint8(2), // source outputs = 2
            uint8(0), // opcode 0 (zeroInputTwoOutput)
            uint8(0x20), // ioByte: 0 inputs, 2 outputs
            uint16(0) // operand
        );
        bytes32[] memory constants = new bytes32[](0);

        vm.expectRevert(abi.encodeWithSelector(StackAllocationMismatch.selector, 2, 3));
        twoOp.runIntegrityCheck(fPointers, bytecode, constants);
    }

    /// StackOutputsMismatch: opcode 0 produces 2 outputs from 0 inputs, so
    /// the final stackIndex is 2. Declaring source outputs = 1 (with correct
    /// stackAllocation = 2) triggers StackOutputsMismatch(2, 1).
    function testStackOutputsMismatch() external {
        IntegrityHighwater twoOp = new IntegrityHighwater();
        bytes memory fPointers = twoOp.buildIntegrityPointers();

        bytes memory bytecode = abi.encodePacked(
            uint8(1), // sourceCount
            uint16(0), // relative offset source 0
            uint8(1), // opsCount
            uint8(2), // stackAllocation = 2 (correct)
            uint8(0), // source inputs = 0
            uint8(1), // source outputs = 1 (WRONG — actual final stack is 2)
            uint8(0), // opcode 0 (zeroInputTwoOutput)
            uint8(0x20), // ioByte: 0 inputs, 2 outputs
            uint16(0) // operand
        );
        bytes32[] memory constants = new bytes32[](0);

        vm.expectRevert(abi.encodeWithSelector(StackOutputsMismatch.selector, 2, 1));
        twoOp.runIntegrityCheck(fPointers, bytecode, constants);
    }
}
