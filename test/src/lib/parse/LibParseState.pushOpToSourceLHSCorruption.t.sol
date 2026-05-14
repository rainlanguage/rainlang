// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibParseState, ParseState, MAX_STACK_RHS_OFFSET} from "../../../../src/lib/parse/LibParseState.sol";
import {OperandV2} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterV4.sol";

/// @title LibParseStatePushOpToSourceLHSCorruptionTest
/// @notice The LHS counter byte at `state + 0x5F` (the last byte of
/// `topLevel1`) belongs to a different counter than the per-item op
/// counters tracked across `topLevel0`/`topLevel1`. `pushOpToSource`
/// computes its write address as `state + 0x20 + stackRHSOffset + 1`, so
/// when the offset takes its maximum allowed value
/// (`MAX_STACK_RHS_OFFSET - 1`) the write must land before byte 0x5F.
/// Pin that boundary directly: any future change to `MAX_STACK_RHS_OFFSET`
/// that lets the offset reach 0x3e silently increments the LHS counter
/// every time an op is pushed to the affected item.
contract LibParseStatePushOpToSourceLHSCorruptionTest is Test {
    using LibParseState for ParseState;

    /// Use the highest offset that `highwater()` will accept. Pre-populate
    /// the per-item op counter so `snapshotSourceHeadToLineTracker` skips
    /// (it only acts when the counter is zero), exercising the bare
    /// `pushOpToSource` increment.
    function testPushOpToSourceAtMaxOffsetDoesNotTouchLHSCounter() external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");

        uint256 offsetAtMax = MAX_STACK_RHS_OFFSET - 1;
        state.topLevel0 = offsetAtMax << 248;

        // Sentinel: byte at `state + 0x5F` (LHS counter, lowest byte of
        // `topLevel1`) = 0xAA. Byte at `state + 0x20 + offset + 1` (the
        // op counter for the current item) = 0x01 so the snapshot guard
        // skips. Layout: `topLevel1`'s lowest byte sits at `state + 0x5F`,
        // the next up at `state + 0x5E`, etc.
        state.topLevel1 = (uint256(0x01) << 8) | uint256(0xAA);

        state.pushOpToSource(0, OperandV2.wrap(0));

        uint8 lhsCounter = uint8(state.topLevel1 & 0xFF);
        assertEq(lhsCounter, 0xAA, "pushOpToSource at max offset corrupted the LHS counter byte at state + 0x5F");
    }
}
