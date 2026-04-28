// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ParseTest} from "test/abstract/ParseTest.sol";
import {UnclosedOperand, UnexpectedOperandValue} from "../../../../src/error/ErrParse.sol";
import {LibParse, ExpectedLeftParen} from "../../../../src/lib/parse/LibParse.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {OperandOverflow} from "../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";

contract LibParseOperandSingleFullTest is ParseTest {
    using LibParse for ParseState;

    /// Fallback is 0 for elided single full operand.
    function testOperandSingleFullElided() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_:b();").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 length
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 outputs
            hex"01"
            // b 0 operand
            hex"03100000"
        );
        assertEq(constants.length, 0);
    }

    /// Empty operand is allowed.
    function testOperandSingleFullEmpty() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_:b<>();").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 length
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 outputs
            hex"01"
            // b 0 operand
            hex"03100000"
        );
        assertEq(constants.length, 0);
    }

    /// Multiple operands are disallowed.
    function testOperandSingleFullMultiple() external {
        vm.expectRevert(abi.encodeWithSelector(UnexpectedOperandValue.selector));
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal("_:b<0x00 0x01>();");
        (bytecode);
        (constants);
    }

    /// Can provide decimal integer 0 as single full operand.
    function testOperandSingleFullZero() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_:b<0>();").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 length
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 outputs
            hex"01"
            // b 0 operand
            hex"03100000"
        );
        assertEq(constants.length, 0);
    }

    /// Can provide hexadecimal 0x00 as a single full operand.
    function testOperandSingleFullHexZero() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_:b<0x00>();").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 length
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 outputs
            hex"01"
            // b 0 operand
            hex"03100000"
        );
        assertEq(constants.length, 0);
    }

    /// Can provide decimal 1 as single full operand.
    function testOperandSingleFullOne() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_:b<1>();").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 length
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 outputs
            hex"01"
            // b 1 operand
            hex"03100001"
        );
        assertEq(constants.length, 0);
    }

    /// Can provide hexadecimal 0x01 as a single full operand.
    function testOperandSingleFullHexOne() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_:b<0x01>();").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 length
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 outputs
            hex"01"
            // b 1 operand
            hex"03100001"
        );
        assertEq(constants.length, 0);
    }

    /// Can provide decimal uint16 max as single full operand.
    function testOperandSingleFullUint16Max() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_:b<65535>();").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 length
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 outputs
            hex"01"
            // b 65535 operand
            hex"0310ffff"
        );
        assertEq(constants.length, 0);
    }

    /// Can provide hexadecimal uint16 max as a single full operand.
    function testOperandSingleFullHexUint16Max() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_:b<0xffff>();").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 length
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 outputs
            hex"01"
            // b 65535 operand
            hex"0310ffff"
        );
        assertEq(constants.length, 0);
    }

    /// Overflowing decimal uint16 max as single full operand reverts.
    function testOperandSingleFullUint16MaxOverflow() external {
        vm.expectRevert(abi.encodeWithSelector(OperandOverflow.selector));
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal("_:b<65536>();");
        (bytecode);
        (constants);
    }

    /// Overflowing hexadecimal uint16 max as a single full operand reverts.
    function testOperandSingleFullHexUint16MaxOverflow() external {
        vm.expectRevert(abi.encodeWithSelector(OperandOverflow.selector));
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal("_:b<0x010000>();");
        (bytecode);
        (constants);
    }

    /// Opening angle bracket without closing angle bracket reverts.
    function testOperandSingleFullUnclosed() external {
        vm.expectRevert(abi.encodeWithSelector(UnclosedOperand.selector, LibParseError.tagErrorOffset(5)));
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal("_:b<0;");
        (bytecode);
        (constants);
    }

    /// Closing angle bracket without opening angle bracket reverts.
    function testOperandSingleFullUnopened() external {
        vm.expectRevert(abi.encodeWithSelector(ExpectedLeftParen.selector, LibParseError.tagErrorOffset(3)));
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal("_:b>0>;");
        (bytecode);
        (constants);
    }

    /// Leading whitespace in the operand is supported.
    function testOperandSingleFullLeadingWhitespace() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_:b< 5>();").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 length
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 outputs
            hex"01"
            // b 5 operand
            hex"03100005"
        );
        assertEq(constants.length, 0);
    }

    /// Trailing whitespace in the operand is supported.
    function testOperandSingleFullTrailingWhitespace() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_:b<5 >();").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 length
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 outputs
            hex"01"
            // b 5 operand
            hex"03100005"
        );
        assertEq(constants.length, 0);
    }

    /// Leading and trailing whitespace in the operand is supported.
    function testOperandSingleFullLeadingAndTrailingWhitespace() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_:b< 0x05 >();").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 length
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 outputs
            hex"01"
            // b 5 operand
            hex"03100005"
        );
        assertEq(constants.length, 0);
    }
}
