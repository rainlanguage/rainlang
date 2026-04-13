// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ParseTest} from "test/abstract/ParseTest.sol";

import {UnexpectedOperand, UnsupportedLiteralType} from "../../../../src/error/ErrParse.sol";
import {LibParse, ExpectedLeftParen} from "../../../../src/lib/parse/LibParse.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";

contract LibParseOperandDisallowedTest is ParseTest {
    using LibParse for ParseState;

    /// Opening an operand is disallowed for words that don't support it.
    function testOperandDisallowed() external {
        vm.expectRevert(abi.encodeWithSelector(UnsupportedLiteralType.selector, LibParseError.tagErrorOffset(4)));
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal("_:a<;");
        (bytecode);
        (constants);
    }

    /// Closing an operand is disallowed for words that don't support it.
    function testOperandDisallowed1() external {
        vm.expectRevert(abi.encodeWithSelector(ExpectedLeftParen.selector, LibParseError.tagErrorOffset(3)));
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal("_:a>;");
        (bytecode);
        (constants);
    }

    /// Opening and closing an operand with a literal is disallowed for words
    /// that don't support it.
    function testOperandDisallowed3() external {
        vm.expectRevert(abi.encodeWithSelector(UnexpectedOperand.selector));
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal("_:a<1>;");
        (bytecode);
        (constants);
    }

    /// Opening and closing an operand with a literal and valid parens is
    /// disallowed for words that don't support it.
    function testOperandDisallowed4() external {
        vm.expectRevert(abi.encodeWithSelector(UnexpectedOperand.selector));
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal("_:a<1>();");
        (bytecode);
        (constants);
    }
}
