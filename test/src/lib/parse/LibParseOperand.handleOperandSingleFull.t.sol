// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseOperand, OperandV2} from "../../../../src/lib/parse/LibParseOperand.sol";
import {UnexpectedOperandValue} from "../../../../src/error/ErrParse.sol";
import {OperandOverflow} from "../../../../src/error/ErrParse.sol";

contract LibParseOperandHandleOperandSingleFullTest is Test {
    function handleOperandSingleFullExternal(bytes32[] memory values) external pure returns (OperandV2) {
        return LibParseOperand.handleOperandSingleFull(values);
    }

    // No values falls back to zero.
    function testHandleOperandSingleFullNoValues() external pure {
        assertEq(OperandV2.unwrap(LibParseOperand.handleOperandSingleFull(new bytes32[](0))), 0);
    }

    // A single value of up to 2 bytes is allowed.
    function testHandleOperandSingleFullSingleValue(uint256 value) external pure {
        value = bound(value, 0, type(uint16).max);
        bytes32[] memory values = new bytes32[](1);
        values[0] = bytes32(value);
        assertEq(OperandV2.unwrap(LibParseOperand.handleOperandSingleFull(values)), bytes32(value));
    }

    // Single values outside 2 bytes are disallowed.
    function testHandleOperandSingleFullSingleValueDisallowed(uint256 value) external {
        value = bound(value, uint256(type(uint16).max) + 1, uint256(int256(type(int128).max)));
        bytes32[] memory values = new bytes32[](1);
        values[0] = bytes32(value);
        vm.expectRevert(abi.encodeWithSelector(OperandOverflow.selector));
        this.handleOperandSingleFullExternal(values);
    }

    // More than one value is disallowed.
    function testHandleOperandSingleFullManyValues(bytes32[] memory values) external {
        vm.assume(values.length > 1);
        vm.expectRevert(abi.encodeWithSelector(UnexpectedOperandValue.selector));
        this.handleOperandSingleFullExternal(values);
    }
}
