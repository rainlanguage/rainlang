// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibBytes, Pointer} from "rain.solmem/lib/LibBytes.sol";
import {LibParseState, ParseState} from "../../../../../src/lib/parse/LibParseState.sol";
import {LibParseLiteral} from "../../../../../src/lib/parse/literal/LibParseLiteral.sol";
import {LibAllStandardOps} from "../../../../../src/lib/op/LibAllStandardOps.sol";
import {IntOrAString, LibIntOrAString} from "rain.intorastring/lib/LibIntOrAString.sol";
import {Float, LibDecimalFloat} from "rain.math.float/lib/LibDecimalFloat.sol";

/// @title LibParseLiteralSelectByIndexTest
/// @notice Directly tests selectLiteralParserByIndex by calling the returned
/// function pointer with known input for each literal type index.
contract LibParseLiteralSelectByIndexTest is Test {
    using LibParseLiteral for ParseState;
    using LibDecimalFloat for Float;
    using LibBytes for bytes;

    /// Index 0 selects the hex parser. Calling it with hex digits
    /// must return the parsed hex value.
    function testSelectIndex0Hex() external view {
        (uint256 cursorAfter, bytes32 value) = this.externalSelectAndParse(0, bytes("0xff"));
        assertEq(value, bytes32(uint256(0xff)));
        (cursorAfter);
    }

    /// Index 1 selects the decimal parser. Calling it with decimal
    /// digits must return the parsed decimal value.
    function testSelectIndex1Decimal() external view {
        (uint256 cursorAfter, bytes32 value) = this.externalSelectAndParse(1, bytes("42e0"));
        assertTrue(Float.wrap(value).eq(LibDecimalFloat.packLossless(42, 0)));
        (cursorAfter);
    }

    /// Index 2 selects the string parser. Calling it with a quoted
    /// string must return the parsed string value.
    function testSelectIndex2String() external view {
        (uint256 cursorAfter, bytes32 value) = this.externalSelectAndParse(2, bytes('"hi"'));
        assertEq(value, bytes32(IntOrAString.unwrap(LibIntOrAString.fromStringV3("hi"))));
        (cursorAfter);
    }

    /// External wrapper that constructs ParseState with real literal
    /// parsers, selects by index, and calls the returned function.
    function externalSelectAndParse(uint256 index, bytes memory data) external view returns (uint256, bytes32) {
        bytes memory literalParsers = LibAllStandardOps.literalParserFunctionPointers();
        ParseState memory state = LibParseState.newState(data, "", "", literalParsers);
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        uint256 end = Pointer.unwrap(data.endDataPointer());

        function(ParseState memory, uint256, uint256) view returns (uint256, bytes32) parser =
            state.selectLiteralParserByIndex(index);
        return parser(state, cursor, end);
    }
}
