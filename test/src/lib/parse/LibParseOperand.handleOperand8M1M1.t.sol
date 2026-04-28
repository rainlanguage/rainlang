// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseOperand, OperandV2} from "../../../../src/lib/parse/LibParseOperand.sol";
import {ExpectedOperand, UnexpectedOperandValue} from "../../../../src/error/ErrParse.sol";
import {OperandOverflow} from "../../../../src/error/ErrParse.sol";

contract LibParseOperandHandleOperand8M1M1Test is Test {
    //forge-lint: disable-next-line(mixed-case-function)
    function handleOperand8M1M1External(bytes32[] memory values) external pure returns (OperandV2) {
        return LibParseOperand.handleOperand8M1M1(values);
    }

    // The first value must be 1 byte and is mandatory. Zero values is an error.
    function testHandleOperand8M1M1NoValues() external {
        vm.expectRevert(abi.encodeWithSelector(ExpectedOperand.selector));
        this.handleOperand8M1M1External(new bytes32[](0));
    }

    // If only the first value is provided, the others default to zero.
    function testHandleOperand8M1M1FirstValueOnly(uint256 value) external pure {
        value = bound(value, 0, type(uint8).max);
        bytes32[] memory values = new bytes32[](1);
        values[0] = bytes32(value);
        assertEq(OperandV2.unwrap(LibParseOperand.handleOperand8M1M1(values)), bytes32(value));
    }

    // If the first value is greater than 1 byte, it is an error.
    function testHandleOperand8M1M1FirstValueTooLarge(int256 value) external {
        value = bound(value, int256(uint256(type(uint8).max)) + 1, type(int128).max);

        bytes32[] memory values = new bytes32[](1);
        // Casting int256 to uint256 does not truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        values[0] = bytes32(uint256(value));
        vm.expectRevert(abi.encodeWithSelector(OperandOverflow.selector));
        this.handleOperand8M1M1External(values);
    }

    // If the first and second values are provided, the third defaults to zero.
    // The first value is 1 byte and the second is 1 bit.
    function testHandleOperand8M1M1FirstAndSecondValue(uint256 a, uint256 b) external pure {
        a = bound(a, 0, type(uint8).max);
        b = bound(b, 0, 1);
        bytes32[] memory values = new bytes32[](2);
        values[0] = bytes32(a);
        values[1] = bytes32(b);
        assertEq(OperandV2.unwrap(LibParseOperand.handleOperand8M1M1(values)), bytes32((b << 8) | a));
    }

    // If the first and second values are provided, the first value is 1 byte
    // but the second is greater than 1 bit, it is an error.
    function testHandleOperand8M1M1FirstAndSecondValueSecondValueTooLarge(uint256 a, uint256 b) external {
        a = bound(a, 0, type(uint8).max);
        b = bound(b, 2, uint256(int256(type(int128).max)));

        bytes32[] memory values = new bytes32[](2);
        values[0] = bytes32(a);
        values[1] = bytes32(b);
        vm.expectRevert(abi.encodeWithSelector(OperandOverflow.selector));
        this.handleOperand8M1M1External(values);
    }

    // If all the values are provided they all appear in the operand.
    // The first value is 1 byte and the second is 1 bit, the third is 1 bit.
    function testHandleOperand8M1M1AllValues(uint256 a, uint256 b, uint256 c) external pure {
        a = bound(a, 0, type(uint8).max);
        b = bound(b, 0, 1);
        c = bound(c, 0, 1);
        bytes32[] memory values = new bytes32[](3);
        values[0] = bytes32(a);
        values[1] = bytes32(b);
        values[2] = bytes32(c);
        assertEq(OperandV2.unwrap(LibParseOperand.handleOperand8M1M1(values)), bytes32((c << 9) | (b << 8) | a));
    }

    // If all the values are provided but the first is greater than 1 byte, it
    // is an error.
    function testHandleOperand8M1M1AllValuesFirstValueTooLarge(int256 a, uint256 b, uint256 c) external {
        a = bound(a, int256(uint256(type(uint8).max)) + 1, type(int128).max);
        b = bound(b, 0, 1);
        c = bound(c, 0, 1);

        bytes32[] memory values = new bytes32[](3);
        //forge-lint: disable-next-line(unsafe-typecast)
        values[0] = bytes32(uint256(a));
        values[1] = bytes32(b);
        values[2] = bytes32(c);
        vm.expectRevert(abi.encodeWithSelector(OperandOverflow.selector));
        this.handleOperand8M1M1External(values);
    }

    // If all the values are provided, the first is 1 byte, the second is 1 bit
    // but the third is greater than 1 bit, it is an error.
    function testHandleOperand8M1M1AllValuesThirdValueTooLarge(uint256 a, uint256 b, uint256 c) external {
        a = bound(a, 0, type(uint8).max);
        b = bound(b, 0, 1);
        c = bound(c, 2, uint256(int256(type(int128).max)));

        bytes32[] memory values = new bytes32[](3);
        values[0] = bytes32(a);
        values[1] = bytes32(b);
        values[2] = bytes32(c);
        vm.expectRevert(abi.encodeWithSelector(OperandOverflow.selector));
        this.handleOperand8M1M1External(values);
    }

    // If more than three values are provided, it is an error.
    function testHandleOperand8M1M1ManyValues(bytes32[] memory values) external {
        vm.assume(values.length > 3);
        vm.expectRevert(abi.encodeWithSelector(UnexpectedOperandValue.selector));
        this.handleOperand8M1M1External(values);
    }
}
