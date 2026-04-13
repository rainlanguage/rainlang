// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";

import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {UnexpectedRightParen} from "../../../../src/error/ErrParse.sol";
import {LibAllStandardOps} from "../../../../src/lib/op/LibAllStandardOps.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";

/// @title LibParseUnexpectedRightParenTest
/// @notice Test that the parser errors when it encounters an unexpected right paren.
contract LibParseUnexpectedRightParenTest is Test {
    using LibParse for ParseState;

    function parseExternal(ParseState memory state)
        external
        view
        returns (bytes memory bytecode, bytes32[] memory constants)
    {
        return state.parse();
    }

    /// Check the parser reverts if it encounters an unexpected right paren.
    function testParseUnexpectedRightParen() external {
        string memory str = ":)";
        ParseState memory state = LibParseState.newState(
            bytes(str),
            LibMetaFixture.parseMetaV2(),
            LibMetaFixture.operandHandlerFunctionPointers(),
            LibAllStandardOps.literalParserFunctionPointers()
        );

        vm.expectRevert(abi.encodeWithSelector(UnexpectedRightParen.selector, LibParseError.tagErrorOffset(1)));
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal(state);
        (bytecode, constants);
    }

    /// The parser should track the paren depth as it encounters left parens.
    function testParseUnexpectedRightParenNested() external {
        string memory str = ":a(b()));";
        ParseState memory state = LibParseState.newState(
            bytes(str),
            LibMetaFixture.parseMetaV2(),
            LibMetaFixture.operandHandlerFunctionPointers(),
            LibAllStandardOps.literalParserFunctionPointers()
        );

        vm.expectRevert(abi.encodeWithSelector(UnexpectedRightParen.selector, LibParseError.tagErrorOffset(7)));
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal(state);
        (bytecode, constants);
    }
}
