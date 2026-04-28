// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {
    ParseState,
    PARSE_STATE_TOP_LEVEL0_OFFSET,
    PARSE_STATE_TOP_LEVEL0_DATA_OFFSET,
    PARSE_STATE_PAREN_TRACKER0_OFFSET,
    PARSE_STATE_LINE_TRACKER_OFFSET
} from "../../../../src/lib/parse/LibParseState.sol";

/// @title LibParseStateOffsetsTest
/// @notice Validates that the named offset constants match the actual memory layout
/// of the `ParseState` struct. Each test writes a sentinel value via Solidity
/// field access and asserts it appears at the expected assembly offset.
contract LibParseStateOffsetsTest is Test {
    function testTopLevel0Offset() external pure {
        ParseState memory state;
        uint256 sentinel = 0xAAAA;
        state.topLevel0 = sentinel;
        uint256 val;
        assembly ("memory-safe") {
            val := mload(add(state, PARSE_STATE_TOP_LEVEL0_OFFSET))
        }
        assertEq(val, sentinel);
    }

    function testTopLevel0DataOffset() external pure {
        assertEq(PARSE_STATE_TOP_LEVEL0_DATA_OFFSET, PARSE_STATE_TOP_LEVEL0_OFFSET + 1);
    }

    function testParenTracker0Offset() external pure {
        ParseState memory state;
        uint256 sentinel = 0xBBBB;
        state.parenTracker0 = sentinel;
        uint256 val;
        assembly ("memory-safe") {
            val := mload(add(state, PARSE_STATE_PAREN_TRACKER0_OFFSET))
        }
        assertEq(val, sentinel);
    }

    function testLineTrackerOffset() external pure {
        ParseState memory state;
        uint256 sentinel = 0xCCCC;
        state.lineTracker = sentinel;
        uint256 val;
        assembly ("memory-safe") {
            val := mload(add(state, PARSE_STATE_LINE_TRACKER_OFFSET))
        }
        assertEq(val, sentinel);
    }
}
