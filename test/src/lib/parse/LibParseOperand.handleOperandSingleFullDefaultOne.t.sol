// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {LibParseOperand, OperandV2} from "../../../../src/lib/parse/LibParseOperand.sol";
import {UnexpectedOperandValue} from "../../../../src/error/ErrParse.sol";
import {OperandOverflow} from "../../../../src/error/ErrParse.sol";

contract LibParseOperandHandleOperandSingleFullDefaultOneTest is Test {
    function handleOperandSingleFullDefaultOneExternal(bytes32[] memory values) external pure returns (OperandV2) {
        return LibParseOperand.handleOperandSingleFullDefaultOne(values);
    }

    // No values falls back to one, which is the whole point of this handler
    // over `handleOperandSingleFull`.
    function testHandleOperandSingleFullDefaultOneNoValues() external pure {
        assertEq(
            OperandV2.unwrap(LibParseOperand.handleOperandSingleFullDefaultOne(new bytes32[](0))), bytes32(uint256(1))
        );
    }

    // A single value of up to 2 bytes is passed through.
    function testHandleOperandSingleFullDefaultOneSingleValue(uint256 value) external pure {
        value = bound(value, 0, type(uint16).max);
        bytes32[] memory values = new bytes32[](1);
        values[0] = bytes32(value);
        assertEq(OperandV2.unwrap(LibParseOperand.handleOperandSingleFullDefaultOne(values)), bytes32(value));
    }

    // AN EXPLICIT ZERO IS PASSED THROUGH AS ZERO, not substituted with the
    // default. Words using this handler reject zero in their own integrity
    // check, and they can only do that if the two cases stay distinguishable
    // here.
    function testHandleOperandSingleFullDefaultOneExplicitZero() external pure {
        bytes32[] memory values = new bytes32[](1);
        values[0] = 0;
        assertEq(OperandV2.unwrap(LibParseOperand.handleOperandSingleFullDefaultOne(values)), 0);
    }

    // Single values outside 2 bytes are disallowed. The parser ORs this
    // handler's result into the source word without masking it, and bit 16 is
    // the low bit of the IO byte that carries the input count, so a value that
    // does not fit would corrupt the operand's neighbour rather than fail.
    function testHandleOperandSingleFullDefaultOneSingleValueDisallowed(uint256 value) external {
        value = bound(value, uint256(type(uint16).max) + 1, uint256(int256(type(int128).max)));
        bytes32[] memory values = new bytes32[](1);
        values[0] = bytes32(value);
        vm.expectRevert(abi.encodeWithSelector(OperandOverflow.selector));
        this.handleOperandSingleFullDefaultOneExternal(values);
    }

    // More than one value is disallowed.
    function testHandleOperandSingleFullDefaultOneManyValues(bytes32[] memory values) external {
        vm.assume(values.length > 1);
        vm.expectRevert(abi.encodeWithSelector(UnexpectedOperandValue.selector));
        this.handleOperandSingleFullDefaultOneExternal(values);
    }
}
