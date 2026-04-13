// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {UnclosedOperand, UnexpectedOperandValue} from "../../../../src/error/ErrParse.sol";
import {LibParse, ExpectedLeftParen} from "../../../../src/lib/parse/LibParse.sol";
import {OperandTest} from "test/abstract/OperandTest.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {OperandOverflow} from "../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";

contract LibParseOperandM1M1Test is OperandTest {
    using LibParse for ParseState;

    /// Default is zero for this operand parser. Tests no operand.
    function testOperandM1M1Elided() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_:d();").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 op
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 output
            hex"01"
            // d operand 0 0
            hex"05100000"
        );
        assertEq(constants.length, 0);
    }

    /// Default is zero for this operand parser. Tests empty operand.
    function testOperandM1M1Empty() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_:d<>();").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 op
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 output
            hex"01"
            // d operand 0 0
            hex"05100000"
        );
        assertEq(constants.length, 0);
    }

    /// Default is zero for this operand parser. Tests first but not second operand.
    function testOperandM1M1First() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_:d<1>();").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 op
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 output
            hex"01"
            // d operand 1 0
            hex"05100001"
        );
        assertEq(constants.length, 0);
    }

    /// Default is zero for this operand parser. Tests first overflow.
    function testOperandM1M1FirstOverflow() external {
        vm.expectRevert(abi.encodeWithSelector(OperandOverflow.selector));
        (bytes memory bytecode, bytes32[] memory constants) = this.parse("_:d<2>();");
        (bytecode);
        (constants);
    }

    /// Default is zero for this operand parser. Tests 0 1.
    function testOperandM1M1Second() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_:d<0 1>();").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 op
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 output
            hex"01"
            // d operand 0 1
            hex"05100002"
        );
        assertEq(constants.length, 0);
    }

    /// Default is zero for this operand parser. Tests 0 0.
    function testOperandM1M1SecondZero() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_:d<0 0>();").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 op
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 output
            hex"01"
            // d operand 0 0
            hex"05100000"
        );
        assertEq(constants.length, 0);
    }

    /// Default is zero for this operand parser. Tests 0 2.
    function testOperandM1M1SecondOverflow() external {
        vm.expectRevert(abi.encodeWithSelector(OperandOverflow.selector));
        (bytes memory bytecode, bytes32[] memory constants) = this.parse("_:d<0 2>();");
        (bytecode);
        (constants);
    }

    /// Default is zero for this operand parser. Tests 1 1.
    function testOperandM1M1Both() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_:d<1 1>();").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 op
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 output
            hex"01"
            // d operand 1 1
            hex"05100003"
        );
        assertEq(constants.length, 0);
    }

    /// Default is zero for this operand parser. Tests 1 1 0.
    function testOperandM1M1BothZero() external {
        checkParseError("_:d<1 1 0>();", abi.encodeWithSelector(UnexpectedOperandValue.selector));
    }

    /// Unclosed operand is disallowed.
    function testOperandM1M1Unclosed() external {
        checkParseError("_:d<1 1();", abi.encodeWithSelector(UnclosedOperand.selector, LibParseError.tagErrorOffset(7)));
        checkParseError("_:d<1 0()", abi.encodeWithSelector(UnclosedOperand.selector, LibParseError.tagErrorOffset(7)));
        checkParseError("_:d<1 ", abi.encodeWithSelector(UnclosedOperand.selector, LibParseError.tagErrorOffset(6)));
        checkParseError("_:d<1", abi.encodeWithSelector(UnclosedOperand.selector, LibParseError.tagErrorOffset(5)));
        checkParseError("_:d<1 1", abi.encodeWithSelector(UnclosedOperand.selector, LibParseError.tagErrorOffset(7)));
    }

    /// Unopened operand is disallowed.
    function testOperandM1M1Unopened() external {
        checkParseError(
            "_:d>1 1>();", abi.encodeWithSelector(ExpectedLeftParen.selector, LibParseError.tagErrorOffset(3))
        );
    }
}
