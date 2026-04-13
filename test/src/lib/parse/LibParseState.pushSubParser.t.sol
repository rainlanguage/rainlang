// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseState, ParseState, SUB_PARSER_POINTER_SHIFT} from "../../../../src/lib/parse/LibParseState.sol";
import {LibBytes, Pointer} from "rain.solmem/lib/LibBytes.sol";
import {InvalidSubParser} from "../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";

/// @title LibParseStatePushSubParserTest
/// @notice Tests for pushing sub parsers onto the parse state.
contract LibParseStatePushSubParserTest is Test {
    using LibParseState for ParseState;
    using LibBytes for bytes;

    function pushSubParserExternal(ParseState memory state, bytes32 value) external pure {
        state.pushSubParser(Pointer.unwrap(state.data.dataPointer()), value);
    }

    /// Pushing any value onto the sub parser that exceeds the maximum value
    /// should revert.
    function testPushSubParserOverflow(ParseState memory state, uint256 value) external {
        value = bound(value, uint256(type(uint160).max) + 1, type(uint256).max);

        state.subParsers = 0;
        vm.expectRevert(abi.encodeWithSelector(InvalidSubParser.selector, LibParseError.tagErrorOffset(0)));
        this.pushSubParserExternal(state, bytes32(value));
    }

    /// Pushing any value onto an empty sub parser LL should result in that value
    /// in the state with a pointer to 0.
    function testPushSubParserZero(ParseState memory state, address value) external pure {
        state.subParsers = 0;
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        state.pushSubParser(cursor, bytes32(uint256(uint160(value))));

        assertEq(uint160(uint256(state.subParsers)), uint160(value));
        uint256 pointer = uint256(state.subParsers) >> SUB_PARSER_POINTER_SHIFT;
        bytes32 deref;
        assembly ("memory-safe") {
            deref := mload(pointer)
        }
        assertEq(deref, 0);
    }

    /// Can push multiple values onto the sub parser LL.
    function testPushSubParserMultiple(ParseState memory state, address value0, address value1, address value2)
        external
        pure
    {
        {
            uint256 cursor = Pointer.unwrap(state.data.dataPointer());
            state.subParsers = 0;
            state.pushSubParser(cursor, bytes32(uint256(uint160(value0))));
            state.pushSubParser(cursor, bytes32(uint256(uint160(value1))));
            state.pushSubParser(cursor, bytes32(uint256(uint160(value2))));
        }

        assertEq(uint160(uint256(state.subParsers)), uint256(uint160(value2)));
        uint256 pointer = uint256(state.subParsers) >> SUB_PARSER_POINTER_SHIFT;
        bytes32 deref;
        assembly ("memory-safe") {
            deref := mload(pointer)
        }
        assertEq(uint160(uint256(deref)), uint256(uint160(value1)));

        pointer = uint256(deref) >> SUB_PARSER_POINTER_SHIFT;
        assembly ("memory-safe") {
            deref := mload(pointer)
        }
        assertEq(uint160(uint256(deref)), uint256(uint160(value0)));

        pointer = uint256(deref) >> SUB_PARSER_POINTER_SHIFT;
        assembly ("memory-safe") {
            deref := mload(pointer)
        }
        assertEq(deref, 0);
    }

    /// Pushing a whole list of values onto the sub parser LL.
    function testPushSubParserList(ParseState memory state, address[] memory values) external pure {
        vm.assume(values.length > 0);
        state.subParsers = 0;
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        for (uint256 i = 0; i < values.length; i++) {
            state.pushSubParser(cursor, bytes32(uint256(uint160(values[i]))));
        }

        uint256 j = values.length - 1;
        bytes32 deref = state.subParsers;
        uint256 pointer = uint256(deref) >> SUB_PARSER_POINTER_SHIFT;
        while (deref != 0) {
            assertEq(uint160(uint256(deref)), uint160(values[j]));

            assembly ("memory-safe") {
                deref := mload(pointer)
            }
            pointer = uint256(deref) >> SUB_PARSER_POINTER_SHIFT;
            // This underflows exactly when deref is zero and the loop
            // terminates.
            unchecked {
                --j;
            }
        }
    }
}
