// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseOperand, OperandV2} from "../../../../src/lib/parse/LibParseOperand.sol";
import {UnexpectedOperandValue} from "../../../../src/error/ErrParse.sol";
import {OperandOverflow} from "../../../../src/error/ErrParse.sol";

contract LibParseOperandHandleOperandM1M1Test is Test {
    //forge-lint: disable-next-line(mixed-case-function)
    function handleOperandM1M1External(bytes32[] memory values) external pure returns (OperandV2) {
        return LibParseOperand.handleOperandM1M1(values);
    }

    // Both values are optional so if nothing is provided everything falls back
    // to zero.
    function testHandleOperandM1M1NoValues() external pure {
        assertEq(OperandV2.unwrap(LibParseOperand.handleOperandM1M1(new bytes32[](0))), 0);
    }

    // If one value is provided it must be 1 bit.
    function testHandleOperandM1M1OneValue(uint256 value) external pure {
        value = bound(value, 0, 1);
        bytes32[] memory values = new bytes32[](1);
        values[0] = bytes32(value);
        assertEq(OperandV2.unwrap(LibParseOperand.handleOperandM1M1(values)), bytes32(value));
    }

    // If one value is provided and it is greater than 1 bit, it is an error.
    function testHandleOperandM1M1OneValueTooLarge(uint256 value) external {
        value = bound(value, 2, uint256(int256(type(int128).max)));

        bytes32[] memory values = new bytes32[](1);
        values[0] = bytes32(value);
        vm.expectRevert(abi.encodeWithSelector(OperandOverflow.selector));
        this.handleOperandM1M1External(values);
    }

    // If two values are provided, they must be 1 bit each.
    function testHandleOperandM1M1TwoValues(uint256 a, uint256 b) external pure {
        a = bound(a, 0, 1);
        b = bound(b, 0, 1);
        bytes32[] memory values = new bytes32[](2);
        values[0] = bytes32(a);
        values[1] = bytes32(b);
        assertEq(OperandV2.unwrap(LibParseOperand.handleOperandM1M1(values)), bytes32((b << 1) | a));
    }

    // If two values are provided and the second is greater than 1 bit, it is
    // an error.
    function testHandleOperandM1M1TwoValuesSecondValueTooLarge(uint256 a, uint256 b) external {
        a = bound(a, 0, 1);
        b = bound(b, 2, uint256(int256(type(int128).max)));

        bytes32[] memory values = new bytes32[](2);
        values[0] = bytes32(a);
        values[1] = bytes32(b);
        vm.expectRevert(abi.encodeWithSelector(OperandOverflow.selector));
        this.handleOperandM1M1External(values);
    }

    // If two values are provided and the first is greater than 1 bit, it is
    // an error.
    function testHandleOperandM1M1TwoValuesFirstValueTooLarge(uint256 a, uint256 b) external {
        a = bound(a, 2, uint256(int256(type(int128).max)));
        b = bound(b, 0, 1);

        bytes32[] memory values = new bytes32[](2);
        values[0] = bytes32(a);
        values[1] = bytes32(b);
        vm.expectRevert(abi.encodeWithSelector(OperandOverflow.selector));
        this.handleOperandM1M1External(values);
    }

    // If more than two values are provided, it is an error.
    function testHandleOperandM1M1ManyValues(bytes32[] memory values) external {
        vm.assume(values.length > 2);
        vm.expectRevert(abi.encodeWithSelector(UnexpectedOperandValue.selector));
        this.handleOperandM1M1External(values);
    }
}
