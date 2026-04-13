// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibParseError, MAGIC_NUMBER_RAIN_PARSE_ERROR_V1} from "../../../../src/lib/parse/LibParseError.sol";
import {LibAllStandardOps} from "../../../../src/lib/op/LibAllStandardOps.sol";

/// @title LibParseErrorTest
/// @notice Unit tests for parseErrorOffset and handleErrorSelector.
contract LibParseErrorTest is Test {
    using LibParseError for ParseState;

    /// parseErrorOffset returns 0 when cursor points to the first byte of data.
    function testParseErrorOffsetFirstByte() external pure {
        bytes memory data = "hello";
        ParseState memory state = LibParseState.newState(data, "", "", "");
        uint256 cursor;
        assembly ("memory-safe") {
            cursor := add(data, 0x20)
        }
        uint256 offset = state.parseErrorOffset(cursor);
        assertTrue(LibParseError.isRainParseError(offset));
        assertEq(LibParseError.parseOffset(offset), 0);
    }

    /// parseErrorOffset returns magic-tagged data.length - 1 when cursor
    /// points to the last byte.
    function testParseErrorOffsetLastByte() external pure {
        bytes memory data = "hello";
        ParseState memory state = LibParseState.newState(data, "", "", "");
        uint256 cursor;
        assembly ("memory-safe") {
            cursor := add(add(data, 0x20), sub(mload(data), 1))
        }
        uint256 offset = state.parseErrorOffset(cursor);
        assertTrue(LibParseError.isRainParseError(offset));
        assertEq(LibParseError.parseOffset(offset), 4);
    }

    /// parseErrorOffset works with a fuzzed cursor within data bounds.
    /// The raw offset always equals the cursor index.
    function testParseErrorOffsetFuzz(uint8 dataLength, uint8 cursorIndex) external pure {
        dataLength = uint8(bound(dataLength, 1, 255));
        cursorIndex = uint8(bound(cursorIndex, 0, dataLength - 1));
        bytes memory data = new bytes(dataLength);
        ParseState memory state = LibParseState.newState(data, "", "", "");
        uint256 cursor;
        assembly ("memory-safe") {
            cursor := add(add(data, 0x20), cursorIndex)
        }
        uint256 offset = state.parseErrorOffset(cursor);
        assertTrue(LibParseError.isRainParseError(offset));
        assertEq(LibParseError.parseOffset(offset), cursorIndex);
    }

    /// A value without the magic number must not be identified as a Rain
    /// parse error.
    function testIsRainParseErrorFalse(uint256 value) external pure {
        vm.assume(!LibParseError.isRainParseError(value));
        assertFalse(LibParseError.isRainParseError(value));
    }

    /// External wrapper for handleErrorSelector so expectRevert works.
    function externalHandleErrorSelector(bytes memory data, uint256 cursorOffset, bytes4 errorSelector) external pure {
        ParseState memory state = LibParseState.newState(data, "", "", "");
        uint256 cursor;
        assembly ("memory-safe") {
            cursor := add(add(data, 0x20), cursorOffset)
        }
        state.handleErrorSelector(cursor, errorSelector);
    }

    /// tagErrorOffset round-trips with parseOffset.
    function testTagErrorOffsetRoundTrip(uint256 offset) external pure {
        offset = bound(offset, 0, type(uint16).max);
        uint256 tagged = LibParseError.tagErrorOffset(offset);
        assertTrue(LibParseError.isRainParseError(tagged));
        assertEq(LibParseError.parseOffset(tagged), offset);
    }

    /// handleErrorSelector with a non-zero selector reverts with the selector
    /// and the cursor offset.
    function testHandleErrorSelectorReverts() external {
        bytes memory data = "abcdefgh";
        bytes4 selector = bytes4(keccak256("TestError(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, LibParseError.tagErrorOffset(5)));
        this.externalHandleErrorSelector(data, 5, selector);
    }

    /// handleErrorSelector with a zero selector does not revert.
    function testHandleErrorSelectorZeroNoOp() external view {
        this.externalHandleErrorSelector("hello", 3, bytes4(0));
    }
}
