// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibAllStandardOps} from "../../../../src/lib/op/LibAllStandardOps.sol";
import {LibBytes, Pointer} from "rain.solmem/lib/LibBytes.sol";
import {UnsupportedLiteralType} from "../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";

/// @title LibParseStatePushLiteralTest
/// @notice Direct unit tests for pushLiteral.
contract LibParseStatePushLiteralTest is Test {
    using LibParseState for ParseState;
    using LibBytes for bytes;

    /// Helper: creates a parse state initialised for literal parsing.
    function buildState(bytes memory data) internal pure returns (ParseState memory) {
        return LibParseState.newState(data, "", "", LibAllStandardOps.literalParserFunctionPointers());
    }

    /// External wrapper so reverts can be caught via expectRevert.
    function pushLiteralExternal(bytes memory data, uint256 cursorOffset) external view returns (uint256) {
        ParseState memory state = buildState(data);
        uint256 cursor = Pointer.unwrap(data.dataPointer()) + cursorOffset;
        uint256 end = Pointer.unwrap(data.endDataPointer());
        return state.pushLiteral(cursor, end);
    }

    /// A single hex literal should push one constant and advance the cursor.
    function testPushLiteralSingleHex() external view {
        bytes memory data = bytes("0xff");
        ParseState memory state = buildState(data);
        uint256 cursor = Pointer.unwrap(data.dataPointer());
        uint256 end = Pointer.unwrap(data.endDataPointer());

        uint256 cursorAfter = state.pushLiteral(cursor, end);

        // Cursor should advance past the entire literal.
        assertEq(cursorAfter, end, "cursor should reach end");

        // One constant should be in the linked list.
        assertEq(state.constantsBuilder & 0xFFFF, 1, "constants height");

        // The constant value should be 0xff.
        uint256 headPtr = state.constantsBuilder >> 0x10;
        bytes32 value;
        assembly ("memory-safe") {
            value := mload(add(headPtr, 0x20))
        }
        assertEq(value, bytes32(uint256(0xff)), "constant value");

        // Bloom should be set.
        assertTrue(state.constantsBloom != 0, "bloom should be set");
    }

    /// A single decimal literal should push one constant.
    function testPushLiteralSingleDecimal() external view {
        bytes memory data = bytes("42e0");
        ParseState memory state = buildState(data);
        uint256 cursor = Pointer.unwrap(data.dataPointer());
        uint256 end = Pointer.unwrap(data.endDataPointer());

        uint256 cursorAfter = state.pushLiteral(cursor, end);

        assertEq(cursorAfter, end, "cursor should reach end");
        assertEq(state.constantsBuilder & 0xFFFF, 1, "constants height");
    }

    /// Two identical hex literals should deduplicate: height stays 1.
    function testPushLiteralDuplicate() external view {
        // State persists between calls because ParseState is a memory struct.
        bytes memory data1 = bytes("0xff");
        bytes memory data2 = bytes("0xff");

        ParseState memory state = LibParseState.newState("", "", "", LibAllStandardOps.literalParserFunctionPointers());

        // Push first literal.
        {
            uint256 cursor1 = Pointer.unwrap(data1.dataPointer());
            uint256 end1 = Pointer.unwrap(data1.endDataPointer());
            state.pushLiteral(cursor1, end1);
        }
        assertEq(state.constantsBuilder & 0xFFFF, 1, "height after first");

        // Push second identical literal.
        {
            uint256 cursor2 = Pointer.unwrap(data2.dataPointer());
            uint256 end2 = Pointer.unwrap(data2.endDataPointer());
            state.pushLiteral(cursor2, end2);
        }
        // Height should still be 1 because the duplicate was detected.
        assertEq(state.constantsBuilder & 0xFFFF, 1, "height after duplicate");
    }

    /// Two different literals should both be pushed: height becomes 2.
    function testPushLiteralTwoDifferent() external view {
        bytes memory data1 = bytes("0xaa");
        bytes memory data2 = bytes("0xbb");

        ParseState memory state = LibParseState.newState("", "", "", LibAllStandardOps.literalParserFunctionPointers());

        {
            uint256 cursor = Pointer.unwrap(data1.dataPointer());
            uint256 end = Pointer.unwrap(data1.endDataPointer());
            state.pushLiteral(cursor, end);
        }
        assertEq(state.constantsBuilder & 0xFFFF, 1, "height after first");

        {
            uint256 cursor = Pointer.unwrap(data2.dataPointer());
            uint256 end = Pointer.unwrap(data2.endDataPointer());
            state.pushLiteral(cursor, end);
        }
        assertEq(state.constantsBuilder & 0xFFFF, 2, "height after second");

        // Verify both values are in the linked list (LIFO order).
        uint256 headPtr = state.constantsBuilder >> 0x10;
        bytes32 val2;
        uint256 nextPtr;
        assembly ("memory-safe") {
            val2 := mload(add(headPtr, 0x20))
            nextPtr := mload(headPtr)
        }
        assertEq(val2, bytes32(uint256(0xbb)), "second value (head)");

        bytes32 val1;
        assembly ("memory-safe") {
            val1 := mload(add(nextPtr, 0x20))
        }
        assertEq(val1, bytes32(uint256(0xaa)), "first value (tail)");
    }

    /// Unrecognized literal type should revert with UnsupportedLiteralType.
    function testPushLiteralUnsupported() external {
        // 'z' is not a valid literal start character.
        vm.expectRevert(abi.encodeWithSelector(UnsupportedLiteralType.selector, LibParseError.tagErrorOffset(0)));
        this.pushLiteralExternal(bytes("zzz"), 0);
    }
}
