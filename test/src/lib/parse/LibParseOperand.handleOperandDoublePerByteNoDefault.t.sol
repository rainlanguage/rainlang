// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseOperand, OperandV2} from "../../../../src/lib/parse/LibParseOperand.sol";
import {ExpectedOperand, UnexpectedOperandValue} from "../../../../src/error/ErrParse.sol";
import {OperandOverflow} from "../../../../src/error/ErrParse.sol";

contract LibParseOperandHandleOperandDoublePerByteNoDefaultTest is Test {
    function handleOperandDoublePerByteNoDefaultExternal(bytes32[] memory values) external pure returns (OperandV2) {
        return LibParseOperand.handleOperandDoublePerByteNoDefault(values);
    }

    // There must be exactly two values so zero values is an error.
    function testHandleOperandDoublePerByteNoDefaultNoValues() external {
        vm.expectRevert(abi.encodeWithSelector(ExpectedOperand.selector));
        this.handleOperandDoublePerByteNoDefaultExternal(new bytes32[](0));
    }

    // There must be exactly two values so one value is an error.
    function testHandleOperandDoublePerByteNoDefaultOneValue(uint256 value) external {
        value = bound(value, 0, type(uint16).max);
        bytes32[] memory values = new bytes32[](1);
        values[0] = bytes32(value);
        vm.expectRevert(abi.encodeWithSelector(ExpectedOperand.selector));
        this.handleOperandDoublePerByteNoDefaultExternal(values);
    }

    // There must be exactly two values so three or more values is an error.
    function testHandleOperandDoublePerByteNoDefaultManyValues(bytes32[] memory values) external {
        vm.assume(values.length > 2);
        vm.expectRevert(abi.encodeWithSelector(UnexpectedOperandValue.selector));
        this.handleOperandDoublePerByteNoDefaultExternal(values);
    }

    // If the first value is greater than 1 byte, it is an error.
    function testHandleOperandDoublePerByteNoDefaultFirstValueTooLarge(uint256 a, uint256 b) external {
        a = bound(a, uint256(type(uint8).max) + 1, uint256(int256(type(int128).max)));
        b = bound(b, 0, type(uint8).max);

        bytes32[] memory values = new bytes32[](2);
        values[0] = bytes32(a);
        values[1] = bytes32(b);

        vm.expectRevert(abi.encodeWithSelector(OperandOverflow.selector));
        this.handleOperandDoublePerByteNoDefaultExternal(values);
    }

    // If the second value is greater than 1 byte, it is an error.
    function testHandleOperandDoublePerByteNoDefaultSecondValueTooLarge(uint256 a, uint256 b) external {
        a = bound(a, 0, type(uint8).max);
        b = bound(b, uint256(type(uint8).max) + 1, uint256(int256(type(int128).max)));

        bytes32[] memory values = new bytes32[](2);
        values[0] = bytes32(a);
        values[1] = bytes32(b);
        vm.expectRevert(abi.encodeWithSelector(OperandOverflow.selector));
        this.handleOperandDoublePerByteNoDefaultExternal(values);
    }

    // If both values are within 1 byte, it is not an error, the result is the
    // second value shifted left by 8 bits plus the first value. The rightmost
    // bits of the operand are the first value.
    function testHandleOperandDoublePerByteNoDefaultBothValuesWithinOneByte(uint256 a, uint256 b) external pure {
        a = bound(a, 0, type(uint8).max);
        b = bound(b, 0, type(uint8).max);
        bytes32[] memory values = new bytes32[](2);
        values[0] = bytes32(a);
        values[1] = bytes32(b);
        assertEq(OperandV2.unwrap(LibParseOperand.handleOperandDoublePerByteNoDefault(values)), bytes32((b << 8) | a));
    }
}
