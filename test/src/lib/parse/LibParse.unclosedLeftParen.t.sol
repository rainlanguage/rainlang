// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ParseTest} from "test/abstract/ParseTest.sol";
import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {UnclosedLeftParen} from "../../../../src/error/ErrParse.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";

/// @title LibParseUnclosedLeftParenTest
/// @notice Test that the parser errors when it encounters an unclosed left paren.
contract LibParseUnclosedLeftParenTest is ParseTest {
    using LibParse for ParseState;

    /// Check the parser reverts if it encounters an unclosed left paren.
    function testParseUnclosedLeftParen() external {
        vm.expectRevert(abi.encodeWithSelector(UnclosedLeftParen.selector, LibParseError.tagErrorOffset(4)));
        this.parseExternal("_:a(;");
    }

    /// Multiple unclosed left parens should be reported.
    function testParseUnclosedLeftParenNested() external {
        vm.expectRevert(abi.encodeWithSelector(UnclosedLeftParen.selector, LibParseError.tagErrorOffset(20)));
        this.parseExternal("_:a(b(c<0 0>(d(e<0>(;");
    }

    /// The parser should track the paren depth as it encounters left parens
    /// and report if there are any unclosed parens.
    function testParseUnclosedLeftParenNested2() external {
        vm.expectRevert(abi.encodeWithSelector(UnclosedLeftParen.selector, LibParseError.tagErrorOffset(24)));
        this.parseExternal("_:a(b(c<0 0>(d(e<0>())));");
    }

    /// If there are multiple RHS nestings, the parser should still report the
    /// unclosed left parens.
    function testParseUnclosedLeftParenNested3() external {
        // Second nesting is unclosed.
        vm.expectRevert(abi.encodeWithSelector(UnclosedLeftParen.selector, LibParseError.tagErrorOffset(34)));
        this.parseExternal("_:a(b(c<0 0>(d(e<0>())))) e<0>(a();");
    }

    function testParseUnclosedLeftParenNested4() external {
        // First nesting is unclosed.
        vm.expectRevert(abi.encodeWithSelector(UnclosedLeftParen.selector, LibParseError.tagErrorOffset(34)));
        this.parseExternal("_:a(b(c<0 0>(d(e<0>()))) e<0>(a());");
    }
}
