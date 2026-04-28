// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {
    LibParseState,
    ParseState,
    EMPTY_ACTIVE_SOURCE,
    FSM_ACTIVE_SOURCE_MASK
} from "../../../../src/lib/parse/LibParseState.sol";
import {OperandV2} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {MaxSources} from "../../../../src/error/ErrParse.sol";

contract LibParseStateEndSourceTest is Test {
    using LibParseState for ParseState;

    /// After ending a single-op source the sourcesBuilder offset must advance
    /// and a source pointer must be stored.
    function testEndSourceSingleOp() external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");
        assertEq(state.sourcesBuilder >> 0xf0, 0);

        state.pushOpToSource(0, OperandV2.wrap(bytes32(0)));
        state.endSource();

        // Offset advanced by 0x10.
        assertEq(state.sourcesBuilder >> 0xf0, 0x10);

        // A source pointer is stored in the low 16 bits.
        uint256 sourcePtr = state.sourcesBuilder & 0xFFFF;
        assertTrue(sourcePtr != 0);

        // The source bytes length encodes 4 bytes per op + 4 byte prefix.
        bytes32 sourceData;
        assembly ("memory-safe") {
            sourceData := mload(sourcePtr)
        }
        // 1 op = 4 bytes + 4 byte prefix = 8.
        assertEq(uint256(sourceData), 8);
    }

    /// After endSource, the FSM active-source flag must be cleared and
    /// per-source state fields must be reset.
    function testEndSourceResetsState() external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");
        uint256 ptrBefore = state.activeSourcePtr;

        state.pushOpToSource(0, OperandV2.wrap(bytes32(0)));

        // Confirm pushOpToSource dirtied these fields.
        assertTrue(state.fsm & FSM_ACTIVE_SOURCE_MASK != 0);
        assertTrue(state.topLevel0 != 0);
        assertTrue(state.parenTracker0 != 0);

        state.endSource();

        // FSM active-source bit is cleared.
        assertEq(state.fsm & FSM_ACTIVE_SOURCE_MASK, 0);

        // Active source pointer changed (resetSource allocates fresh).
        assertNotEq(state.activeSourcePtr, ptrBefore);

        // New active source has empty offset.
        bytes32 newSource;
        uint256 newPtr = state.activeSourcePtr;
        assembly ("memory-safe") {
            newSource := mload(newPtr)
        }
        assertEq(uint256(newSource) & 0xFFFF, EMPTY_ACTIVE_SOURCE & 0xFFFF);

        // topLevel0 is reset.
        assertEq(state.topLevel0, 0);

        // parenTracker0 is reset.
        assertEq(state.parenTracker0, 0);

        // lineTracker is reset.
        assertEq(state.lineTracker, 0);
    }

    /// Two consecutive sources must store distinct pointers at successive
    /// 16-bit slots in sourcesBuilder.
    function testEndSourceTwoSources() external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");

        state.pushOpToSource(0, OperandV2.wrap(bytes32(0)));
        state.endSource();
        uint256 builderAfterFirst = state.sourcesBuilder;
        assertEq(builderAfterFirst >> 0xf0, 0x10);

        state.pushOpToSource(1, OperandV2.wrap(bytes32(0)));
        state.pushOpToSource(2, OperandV2.wrap(bytes32(0)));
        state.endSource();
        uint256 builderAfterSecond = state.sourcesBuilder;
        assertEq(builderAfterSecond >> 0xf0, 0x20);

        // First source pointer preserved in low 16 bits.
        assertEq(builderAfterSecond & 0xFFFF, builderAfterFirst & 0xFFFF);

        // Second source pointer at bits [0x10, 0x20).
        uint256 secondPtr = (builderAfterSecond >> 0x10) & 0xFFFF;
        assertTrue(secondPtr != 0);
        assertNotEq(secondPtr, builderAfterSecond & 0xFFFF);
    }

    /// Fuzz the op count: source byte length must be 4 * opCount + 4.
    function testEndSourceByteLengthFuzz(uint256 opCount) external pure {
        opCount = bound(opCount, 1, 255);
        ParseState memory state = LibParseState.newState("", "", "", "");

        for (uint256 i = 0; i < opCount; i++) {
            // Safe: i % 256 fits in uint8 by definition.
            //forge-lint: disable-next-line(unsafe-typecast)
            state.pushOpToSource(uint8(i % 256), OperandV2.wrap(bytes32(uint256(i))));
        }
        state.endSource();

        uint256 sourcePtr = state.sourcesBuilder & 0xFFFF;
        bytes32 sourceData;
        assembly ("memory-safe") {
            sourceData := mload(sourcePtr)
        }
        assertEq(uint256(sourceData), opCount * 4 + 4);
    }

    /// External wrapper so expectRevert works for MaxSources.
    function externalEndSource16Times() external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");
        for (uint256 i = 0; i < 16; i++) {
            state.pushOpToSource(0, OperandV2.wrap(bytes32(0)));
            state.endSource();
        }
    }

    /// MaxSources must fire on the 16th endSource call.
    function testEndSourceMaxSources() external {
        vm.expectRevert(abi.encodeWithSelector(MaxSources.selector));
        this.externalEndSource16Times();
    }
}
