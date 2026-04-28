// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {
    LibParseState,
    ParseState,
    EMPTY_ACTIVE_SOURCE,
    FSM_ACTIVE_SOURCE_MASK,
    FSM_ACCEPTING_INPUTS_MASK
} from "../../../../src/lib/parse/LibParseState.sol";
import {OperandV2} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {SourceItemOpsOverflow} from "../../../../src/error/ErrParse.sol";

contract LibParseStatePushOpToSourceTest is Test {
    using LibParseState for ParseState;

    /// After pushing one op, the active source must no longer be empty
    /// and must encode the opcode and operand at the correct bit offset.
    function testPushOpToSourceEncodesOp(uint8 opcode, uint16 operandVal) external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");
        OperandV2 operand = OperandV2.wrap(bytes32(uint256(operandVal)));
        state.pushOpToSource(opcode, operand);

        uint256 activeSourcePointer = state.activeSourcePtr;
        bytes32 activeSource;
        assembly ("memory-safe") {
            activeSource := mload(activeSourcePointer)
        }

        // Active source is no longer empty.
        assertNotEq(uint256(activeSource), EMPTY_ACTIVE_SOURCE);

        // Offset should have advanced from 0x20 to 0x40.
        uint256 offset = uint256(activeSource) & 0xFFFF;
        assertEq(offset, 0x40);

        // Extract the opcode at bits [0x38, 0x40) = byte at offset 0x20+0x18.
        uint256 storedOpcode = (uint256(activeSource) >> 0x38) & 0xFF;
        assertEq(storedOpcode, uint256(opcode));

        // Extract the operand at bits [0x20, 0x38) = 3 bytes at offset 0x20.
        uint256 storedOperand = (uint256(activeSource) >> 0x20) & 0xFFFFFF;
        assertEq(storedOperand, uint256(operandVal));
    }

    /// After pushing, FSM must have active-source set and
    /// accepting-inputs cleared.
    function testPushOpToSourceFSM() external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");
        // FSM starts with accepting-inputs set.
        assertTrue(state.fsm & FSM_ACCEPTING_INPUTS_MASK != 0);
        assertEq(state.fsm & FSM_ACTIVE_SOURCE_MASK, 0);

        state.pushOpToSource(0, OperandV2.wrap(bytes32(0)));

        assertEq(state.fsm & FSM_ACCEPTING_INPUTS_MASK, 0);
        assertTrue(state.fsm & FSM_ACTIVE_SOURCE_MASK != 0);
    }

    /// Two consecutive pushes must encode both ops at successive offsets.
    function testPushOpToSourceTwoOps(uint8 op0, uint16 operand0, uint8 op1, uint16 operand1) external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");
        state.pushOpToSource(op0, OperandV2.wrap(bytes32(uint256(operand0))));
        state.pushOpToSource(op1, OperandV2.wrap(bytes32(uint256(operand1))));

        uint256 activeSourcePointer = state.activeSourcePtr;
        bytes32 activeSource;
        assembly ("memory-safe") {
            activeSource := mload(activeSourcePointer)
        }

        // Offset should be 0x60 after two pushes (0x20 + 0x20 + 0x20).
        assertEq(uint256(activeSource) & 0xFFFF, 0x60);

        // First op at bit offset 0x20.
        assertEq((uint256(activeSource) >> 0x38) & 0xFF, uint256(op0));
        assertEq((uint256(activeSource) >> 0x20) & 0xFFFFFF, uint256(operand0));

        // Second op at bit offset 0x40.
        assertEq((uint256(activeSource) >> 0x58) & 0xFF, uint256(op1));
        assertEq((uint256(activeSource) >> 0x40) & 0xFFFFFF, uint256(operand1));
    }

    /// Pushing 7 ops fills a source slot (offset reaches 0xe0) and must
    /// allocate a new active source pointer.
    function testPushOpToSourceSlotOverflow() external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");
        uint256 initialPtr = state.activeSourcePtr;

        for (uint256 i = 0; i < 7; i++) {
            // Safe: i < 7, fits in uint8.
            //forge-lint: disable-next-line(unsafe-typecast)
            state.pushOpToSource(uint8(i), OperandV2.wrap(bytes32(0)));
        }

        // After 7 pushes the slot is full and a new pointer was allocated.
        uint256 newPtr = state.activeSourcePtr;
        assertNotEq(newPtr, initialPtr);

        // The new active source has EMPTY_ACTIVE_SOURCE offset (0x20) in the
        // low 16 bits, with the old pointer stored at bits [0x10, 0x30).
        bytes32 newSource;
        assembly ("memory-safe") {
            newSource := mload(newPtr)
        }
        assertEq(uint256(newSource) & 0xFFFF, EMPTY_ACTIVE_SOURCE & 0xFFFF);
        assertEq((uint256(newSource) >> 0x10) & 0xFFFF, initialPtr);
    }

    /// SourceItemOpsOverflow must fire when the top-level counter hits 0xFF.
    function externalPushOpsUntilOverflow() external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");
        for (uint256 i = 0; i < 256; i++) {
            state.pushOpToSource(0, OperandV2.wrap(bytes32(0)));
        }
    }

    function testPushOpToSourceItemOpsOverflow() external {
        vm.expectRevert(abi.encodeWithSelector(SourceItemOpsOverflow.selector));
        this.externalPushOpsUntilOverflow();
    }
}
