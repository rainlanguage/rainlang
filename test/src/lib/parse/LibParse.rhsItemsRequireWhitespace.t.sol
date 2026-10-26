// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ParseTest} from "test/abstract/ParseTest.sol";
import {UnexpectedRHSChar} from "../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";

/// @title LibParseRHSItemsRequireWhitespaceTest
/// @notice A completed RHS item (literal, word, closed paren group) must be
/// separated from a following literal or word by whitespace.
contract LibParseRHSItemsRequireWhitespaceTest is ParseTest {
    function checkAdjacentReverts(string memory s, uint256 offset) internal {
        vm.expectRevert(abi.encodeWithSelector(UnexpectedRHSChar.selector, LibParseError.tagErrorOffset(offset)));
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal(s);
        (bytecode, constants);
    }

    function checkParses(string memory s, uint256 expectedConstants) internal view {
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal(s);
        assertTrue(bytecode.length > 0);
        assertEq(constants.length, expectedConstants);
    }

    function testParseRHSDecimalThenNegativeDecimalReverts() external {
        checkAdjacentReverts("_ _:1-2;", 5);
    }

    function testParseRHSHexThenStringReverts() external {
        checkAdjacentReverts("_ _:0x01\"a\";", 8);
    }

    function testParseRHSDecimalThenStringReverts() external {
        checkAdjacentReverts("_ _:1\"a\";", 5);
    }

    function testParseRHSDecimalThenSubParseableReverts() external {
        checkAdjacentReverts("_ _:1[x y];", 5);
    }

    function testParseRHSStringThenDecimalReverts() external {
        checkAdjacentReverts("_ _:\"a\"1;", 7);
    }

    function testParseRHSStringThenStringReverts() external {
        checkAdjacentReverts("_ _:\"a\"\"b\";", 7);
    }

    function testParseRHSStringThenWordReverts() external {
        checkAdjacentReverts("_ _:\"a\"b;", 7);
    }

    function testParseRHSStackNameThenStringReverts() external {
        checkAdjacentReverts("foo:1,_:foo\"x\";", 11);
    }

    function testParseRHSStackNameThenSubParseableReverts() external {
        checkAdjacentReverts("foo:1,_:foo[x y];", 11);
    }

    function testParseRHSParenCloseAfterLiteralThenLiteralReverts() external {
        checkAdjacentReverts("_ _:a(1 2)3;", 10);
    }

    function testParseRHSParenCloseAfterWhitespaceThenLiteralReverts() external {
        checkAdjacentReverts("_ _:a(1 2 )3;", 11);
    }

    function testParseRHSParenCloseAfterWhitespaceThenStringReverts() external {
        checkAdjacentReverts("_ _:a(1 2 )\"a\";", 11);
    }

    function testParseRHSParenCloseAfterWhitespaceThenWordReverts() external {
        checkAdjacentReverts("_ _:a(1 2 )b();", 11);
    }

    function testParseRHSEmptyParenCloseThenWordReverts() external {
        checkAdjacentReverts("_ _:a()b();", 7);
    }

    function testParseRHSNestedParenCloseThenLiteralReverts() external {
        checkAdjacentReverts("_ _:a(a(1 2 ))3;", 14);
    }

    function testParseRHSWhitespaceSeparatedLiteralsParse() external view {
        checkParses("_ _:1 2;", 2);
        checkParses("_ _:1 -2;", 2);
        checkParses("_ _:\"a\" \"b\";", 2);
        checkParses("_ _:\"a\" 1;", 2);
        checkParses("_ _:0x01 \"a\";", 2);
    }

    function testParseRHSWhitespaceSeparatedStackNameParses() external view {
        checkParses("foo:1,_ _:foo \"x\";", 2);
    }

    function testParseRHSWhitespaceSeparatedParenGroupsParse() external view {
        checkParses("_ _:a(1 2) 3;", 3);
        checkParses("_ _:a(1 2)\n3;", 3);
        checkParses("_ _:a(1 2 ) b(3 4);", 4);
        checkParses("_ _:a() b();", 0);
        checkParses("_:a(a(1 2) 3);", 3);
        checkParses("_:a(a(1 2));", 2);
        checkParses("_:a(1 2),_:3;", 3);
    }
}
