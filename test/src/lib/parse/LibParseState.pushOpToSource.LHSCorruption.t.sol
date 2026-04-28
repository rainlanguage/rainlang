// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {OperandV2} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

/// @title LibParseStatePushOpToSourceLHSCorruptionTest
/// @notice Tests the boundary between the per-word ops counters in
/// topLevel0/topLevel1 and the LHS counter byte at the end of topLevel1.
/// RHS offset 62 collides with the LHS counter byte at state + 0x5F.
/// RHS offset 61 is the last offset that writes to a legitimate counter.
contract LibParseStatePushOpToSourceLHSCorruptionTest is Test {
    using LibParseState for ParseState;

    /// RHS offset 62 causes pushOpToSource to compute the counter
    /// pointer as state + 0x20 + 62 + 1 = state + 0x5F, which is the
    /// LHS counter byte. The op increment writes to the wrong location.
    function testPushOpAtOffset62CorruptsLHSCounter() external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");

        uint256 lhsBefore = state.topLevel1 & 0xFF;
        assertEq(lhsBefore, 0, "LHS counter should start at 0");

        // Set the RHS offset to 62.
        state.topLevel0 = uint256(62) << 248;

        // Set lineTracker snapshot to 62 to keep lineRHSTopLevel = 0.
        state.lineTracker = 62 << 8;

        state.pushOpToSource(0, OperandV2.wrap(bytes32(0)));

        // The LHS counter byte is corrupted — it reads 1 instead of 0.
        uint256 lhsAfter = state.topLevel1 & 0xFF;
        assertEq(lhsAfter, 1, "LHS counter byte at offset 62 is the collision target");
    }

    /// RHS offset 61 computes the counter pointer as state + 0x20 + 61
    /// + 1 = state + 0x5E, which is a legitimate per-word ops counter
    /// in topLevel1. The LHS counter is not affected.
    function testPushOpAtOffset61DoesNotCorruptLHS() external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");

        assertEq(state.topLevel1 & 0xFF, 0, "LHS counter should start at 0");

        // Set the RHS offset to 61.
        state.topLevel0 = uint256(61) << 248;

        // Set lineTracker snapshot to 61 to keep lineRHSTopLevel = 0.
        state.lineTracker = 61 << 8;

        state.pushOpToSource(0, OperandV2.wrap(bytes32(0)));

        // LHS counter must still be 0.
        assertEq(state.topLevel1 & 0xFF, 0, "LHS counter must not be affected at offset 61");
    }
}
