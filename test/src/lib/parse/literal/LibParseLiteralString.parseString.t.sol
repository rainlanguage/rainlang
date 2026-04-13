// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseLiteralString} from "../../../../../src/lib/parse/literal/LibParseLiteralString.sol";
import {LibBytes, Pointer} from "rain.solmem/lib/LibBytes.sol";
import {IntOrAString, LibIntOrAString} from "rain.intorastring/lib/LibIntOrAString.sol";
import {LibParseState, ParseState} from "../../../../../src/lib/parse/LibParseState.sol";
import {CMASK_STRING_LITERAL_TAIL} from "rain.string/lib/parse/LibParseCMask.sol";
import {LibConformString} from "rain.string/lib/mut/LibConformString.sol";
import {UnclosedStringLiteral} from "../../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../../src/lib/parse/LibParseError.sol";

/// @title LibParseLiteralStringTest
/// @notice Tests parsing strings with the LibParseLiteral library.
contract LibParseLiteralStringTest is Test {
    using LibBytes for bytes;
    using LibParseLiteralString for ParseState;

    function parseStringExternal(ParseState memory state) external pure returns (uint256 cursorAfter, bytes32 value) {
        return state.parseString(Pointer.unwrap(state.data.dataPointer()), Pointer.unwrap(state.data.endDataPointer()));
    }

    /// Check that an empty string literal is parsed correctly.
    function testParseStringLiteralEmpty() external pure {
        ParseState memory state = LibParseState.newState("\"\"", "", "", "");
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        (uint256 cursorAfter, bytes32 value) = state.parseString(cursor, Pointer.unwrap(state.data.endDataPointer()));
        // Empty string is length 0 with the 3 truth bits set, which is
        // 0b11100000 or 0xe0 in hexadecimal.
        assertEq(value, bytes32(uint256(0xe0)));
        assertEq(cursorAfter, cursor + 2);
    }

    /// The parser will only accept strings that are valid according to the mask.
    function testParseStringLiteralAny(bytes memory data) external pure {
        LibConformString.conformStringToMask(string(data), CMASK_STRING_LITERAL_TAIL, 0x80);
        vm.assume(data.length < 32);
        ParseState memory state = LibParseState.newState(bytes(string.concat("\"", string(data), "\"")), "", "", "");

        uint256 expectedValue = IntOrAString.unwrap(LibIntOrAString.fromStringV3(string(data)));
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        (uint256 cursorAfter, bytes32 value) =
            state.parseString(Pointer.unwrap(state.data.dataPointer()), Pointer.unwrap(state.data.endDataPointer()));
        assertEq(value, bytes32(expectedValue));
        assertEq(cursorAfter, cursor + data.length + 2);
    }

    /// parseString temporarily overwrites memory before the string content
    /// with a length prefix, then restores it. Verify the data bytes are
    /// intact after parsing by checking that a second parse of the same
    /// data produces the same result.
    function testParseStringMemoryRestoration(bytes memory data) external pure {
        LibConformString.conformStringToMask(string(data), CMASK_STRING_LITERAL_TAIL, 0x80);
        vm.assume(data.length > 0 && data.length < 32);
        bytes memory wrapped = bytes(string.concat("\"", string(data), "\""));
        ParseState memory state = LibParseState.newState(wrapped, "", "", "");
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        uint256 end = Pointer.unwrap(state.data.endDataPointer());

        (, bytes32 value1) = state.parseString(cursor, end);
        // If memory was not restored, the data length or content would be
        // corrupted and the second parse would produce a different result
        // or revert.
        (, bytes32 value2) = state.parseString(cursor, end);
        assertEq(value1, value2, "memory restoration: values differ");
        assertEq(state.data.length, wrapped.length, "memory restoration: data length corrupted");
    }

    /// If any character in the string is not in the mask, the parser will error.
    function testParseStringLiteralCorrupt(bytes memory data, uint256 corruptIndex) external {
        vm.assume(data.length > 0);
        LibConformString.conformStringToMask(string(data), CMASK_STRING_LITERAL_TAIL, 0x80);
        vm.assume(data.length < 32);
        corruptIndex = bound(corruptIndex, 0, data.length - 1);
        LibConformString.corruptSingleChar(string(data), corruptIndex);

        ParseState memory state = LibParseState.newState(bytes(string.concat("\"", string(data), "\"")), "", "", "");

        vm.expectRevert(
            abi.encodeWithSelector(UnclosedStringLiteral.selector, LibParseError.tagErrorOffset(1 + corruptIndex))
        );
        (uint256 cursorAfter, bytes32 value) = this.parseStringExternal(state);
        (cursorAfter, value);
    }
}
