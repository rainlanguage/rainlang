// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibBytes, Pointer} from "rain.solmem/lib/LibBytes.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibParseInterstitial} from "../../../../src/lib/parse/LibParseInterstitial.sol";
import {FSM_YANG_MASK} from "../../../../src/lib/parse/LibParseState.sol";
import {MalformedCommentStart, UnclosedComment} from "../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";

/// @title LibParseInterstitialTest
/// @notice Tests for LibParseInterstitial.
contract LibParseInterstitialTest is Test {
    using LibParseInterstitial for ParseState;
    using LibBytes for bytes;

    /// Any second byte other than '*' after '/' must revert with
    /// MalformedCommentStart. Data must be >= 4 bytes to pass the
    /// UnclosedComment check first.
    function testMalformedCommentStart(uint8 secondByte) external {
        vm.assume(secondByte != 0x2A); // not '*'
        // Safe: single-byte values fit in bytes1; "*/" fits in bytes2.
        //forge-lint: disable-next-line(unsafe-typecast)
        bytes memory data = abi.encodePacked(bytes1("/"), bytes1(secondByte), bytes2("*/"));

        vm.expectRevert(abi.encodeWithSelector(MalformedCommentStart.selector, LibParseError.tagErrorOffset(0)));
        this.externalSkipComment(data);
    }

    /// External wrapper that constructs ParseState internally so memory
    /// pointers remain valid across the external call boundary.
    function externalSkipComment(bytes memory data) external pure returns (uint256) {
        ParseState memory state = LibParseState.newState(data, "", "", "");
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        return state.skipComment(cursor, Pointer.unwrap(data.endDataPointer()));
    }

    /// skipComment with fewer than 4 bytes reverts with UnclosedComment.
    function testSkipCommentTooShort() external {
        vm.expectRevert(abi.encodeWithSelector(UnclosedComment.selector, LibParseError.tagErrorOffset(0)));
        this.externalSkipComment(bytes("/*"));
    }

    /// skipComment with exactly 3 bytes reverts with UnclosedComment.
    function testSkipCommentThreeBytes() external {
        vm.expectRevert(abi.encodeWithSelector(UnclosedComment.selector, LibParseError.tagErrorOffset(0)));
        this.externalSkipComment(bytes("/* "));
    }

    /// skipComment sets yang mask.
    function testSkipCommentSetsYang() external pure {
        bytes memory data = "/**/x";
        ParseState memory state = LibParseState.newState(data, "", "", "");
        assertEq(state.fsm & FSM_YANG_MASK, 0, "yang initially clear");
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        uint256 end = Pointer.unwrap(data.endDataPointer());
        cursor = state.skipComment(cursor, end);
        assertTrue(state.fsm & FSM_YANG_MASK > 0, "yang set after comment");
        uint256 charAtCursor;
        assembly ("memory-safe") {
            charAtCursor := byte(0, mload(cursor))
        }
        // Safe: "x" is a single ASCII character.
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(charAtCursor, uint256(uint8(bytes1("x"))), "cursor at x");
    }

    /// skipWhitespace clears yang mask and advances cursor.
    function testSkipWhitespaceClearsYang() external pure {
        bytes memory data = " x";
        ParseState memory state = LibParseState.newState(data, "", "", "");
        state.fsm |= FSM_YANG_MASK;
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        uint256 end = Pointer.unwrap(data.endDataPointer());
        cursor = state.skipWhitespace(cursor, end);
        assertEq(state.fsm & FSM_YANG_MASK, 0, "yang cleared");
        uint256 charAtCursor;
        assembly ("memory-safe") {
            charAtCursor := byte(0, mload(cursor))
        }
        // Safe: "x" is a single ASCII character.
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(charAtCursor, uint256(uint8(bytes1("x"))), "cursor at x");
    }

    /// skipWhitespace at end returns cursor unchanged.
    function testSkipWhitespaceAtEnd() external pure {
        bytes memory data = "x";
        ParseState memory state = LibParseState.newState(data, "", "", "");
        uint256 end = Pointer.unwrap(data.endDataPointer());
        uint256 result = state.skipWhitespace(end, end);
        assertEq(result, end, "cursor unchanged at end");
    }

    /// parseInterstitial skips mixed whitespace and comments.
    function testParseInterstitialMixed() external pure {
        bytes memory data = "  /* comment */  x";
        ParseState memory state = LibParseState.newState(data, "", "", "");
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        uint256 end = Pointer.unwrap(data.endDataPointer());
        cursor = state.parseInterstitial(cursor, end);
        uint256 charAtCursor;
        assembly ("memory-safe") {
            charAtCursor := byte(0, mload(cursor))
        }
        // Safe: "x" is a single ASCII character.
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(charAtCursor, uint256(uint8(bytes1("x"))), "cursor at x");
    }

    /// parseInterstitial at end returns cursor unchanged.
    function testParseInterstitialAtEnd() external pure {
        bytes memory data = "x";
        ParseState memory state = LibParseState.newState(data, "", "", "");
        uint256 end = Pointer.unwrap(data.endDataPointer());
        uint256 result = state.parseInterstitial(end, end);
        assertEq(result, end, "cursor unchanged at end");
    }

    /// skipWhitespace advances over tab, newline, and carriage return.
    function testSkipWhitespaceAllTypes() external pure {
        // space, tab, newline, carriage return, then 'x'
        bytes memory data = hex"20090a0d78";
        ParseState memory state = LibParseState.newState(data, "", "", "");
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        uint256 end = Pointer.unwrap(data.endDataPointer());
        cursor = state.skipWhitespace(cursor, end);
        uint256 charAtCursor;
        assembly ("memory-safe") {
            charAtCursor := byte(0, mload(cursor))
        }
        // Safe: "x" is a single ASCII character.
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(charAtCursor, uint256(uint8(bytes1("x"))), "cursor at x after all ws types");
    }

    /// skipComment advances past a comment with content inside.
    function testSkipCommentWithContent() external pure {
        bytes memory data = "/* hello world */x";
        ParseState memory state = LibParseState.newState(data, "", "", "");
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        uint256 end = Pointer.unwrap(data.endDataPointer());
        cursor = state.skipComment(cursor, end);
        uint256 charAtCursor;
        assembly ("memory-safe") {
            charAtCursor := byte(0, mload(cursor))
        }
        // Safe: "x" is a single ASCII character.
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(charAtCursor, uint256(uint8(bytes1("x"))), "cursor at x after content comment");
    }

    /// Fuzz: skipComment with arbitrary body content always lands cursor
    /// immediately after the closing `*/`.
    function testSkipCommentFuzzBody(bytes memory body) external pure {
        // Replace all `*` in body with `~` so no `*/` can appear.
        for (uint256 i = 0; i < body.length; i++) {
            // Casting single ASCII chars to bytes1 is safe.
            //forge-lint: disable-next-line(unsafe-typecast)
            if (body[i] == bytes1("*")) {
                //forge-lint: disable-next-line(unsafe-typecast)
                body[i] = bytes1("~");
            }
        }

        // Build: /* <body> */ x
        bytes memory data = abi.encodePacked("/*", body, "*/x");

        ParseState memory state = LibParseState.newState(data, "", "", "");
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        uint256 end = Pointer.unwrap(data.endDataPointer());
        cursor = state.skipComment(cursor, end);

        // Cursor should be at 'x', which is one byte before end.
        assertEq(cursor, end - 1, "cursor at x after fuzzed comment");
        uint256 charAtCursor;
        assembly ("memory-safe") {
            charAtCursor := byte(0, mload(cursor))
        }
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(charAtCursor, uint256(uint8(bytes1("x"))), "char is x");
    }

    /// parseInterstitial returns immediately when first character is not
    /// whitespace or comment head.
    function testParseInterstitialNonInterstitialFirst() external pure {
        bytes memory data = "xyz";
        ParseState memory state = LibParseState.newState(data, "", "", "");
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        uint256 end = Pointer.unwrap(data.endDataPointer());
        uint256 result = state.parseInterstitial(cursor, end);
        assertEq(result, cursor, "cursor unchanged on non-interstitial");
    }

    /// parseInterstitial skips multiple consecutive comments.
    function testParseInterstitialMultipleComments() external pure {
        bytes memory data = "/* a */ /* b */ /* c */x";
        ParseState memory state = LibParseState.newState(data, "", "", "");
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        uint256 end = Pointer.unwrap(data.endDataPointer());
        cursor = state.parseInterstitial(cursor, end);
        uint256 charAtCursor;
        assembly ("memory-safe") {
            charAtCursor := byte(0, mload(cursor))
        }
        // Safe: "x" is a single ASCII character.
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(charAtCursor, uint256(uint8(bytes1("x"))), "cursor at x after multiple comments");
    }
}
