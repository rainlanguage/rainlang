// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibOpBitwiseAnd} from "../../../../../src/lib/op/bitwise/LibOpBitwiseAnd.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {UnexpectedOperand} from "../../../../../src/error/ErrParse.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";

contract LibOpBitwiseAndTest is OpTest {
    /// Directly test the integrity logic of LibOpBitwiseAnd. All possible
    /// operands result in the same number of inputs and outputs, (2, 1).
    function testOpBitwiseAndIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpBitwiseAnd.integrity(state, operand);
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpBitwiseAnd. This tests that the
    /// opcode correctly pushes the bitwise AND onto the stack.
    function testOpBitwiseAndRun(StackItem x, StackItem y) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = x;
        inputs[1] = y;
        OperandV2 operand = LibOperand.build(2, 1, 0);
        opReferenceCheck(
            state, operand, LibOpBitwiseAnd.referenceFn, LibOpBitwiseAnd.integrity, LibOpBitwiseAnd.run, inputs
        );
    }

    /// Test the eval of bitwise AND parsed from a string.
    function testOpBitwiseAndEvalHappy() external view {
        checkHappy("_: bitwise-and(0x00 0x00);", 0, "0 0");
        checkHappy("_: bitwise-and(0x00 0x01);", 0, "0 1");
        checkHappy("_: bitwise-and(0x01 0x00);", 0, "1 0");
        checkHappy("_: bitwise-and(0x01 0x01);", bytes32(uint256(1)), "1 1");
        checkHappy("_: bitwise-and(0x00 0x02);", 0, "0 2");
        checkHappy("_: bitwise-and(0x02 0x00);", 0, "2 0");
        checkHappy("_: bitwise-and(0x01 0x02);", 0, "1 2");
        checkHappy("_: bitwise-and(0x02 0x01);", 0, "2 1");
        checkHappy("_: bitwise-and(0x02 0x02);", bytes32(uint256(2)), "2 2");
        checkHappy("_: bitwise-and(0x00 0x03);", 0, "0 3");
        checkHappy("_: bitwise-and(0x03 0x00);", 0, "3 0");
        checkHappy("_: bitwise-and(0x01 0x03);", bytes32(uint256(1)), "1 3");
        checkHappy("_: bitwise-and(0x03 0x01);", bytes32(uint256(1)), "3 1");
        checkHappy("_: bitwise-and(0x02 0x03);", bytes32(uint256(2)), "2 3");
        checkHappy("_: bitwise-and(0x03 0x02);", bytes32(uint256(2)), "3 2");
        checkHappy("_: bitwise-and(0x03 0x03);", bytes32(uint256(3)), "3 3");
    }

    /// Test that a bitwise OR with bad inputs fails integrity.
    function testOpBitwiseOREvalZeroInputs() external {
        checkBadInputs("_: bitwise-and();", 0, 2, 0);
    }

    function testOpBitwiseOREvalOneInput() external {
        checkBadInputs("_: bitwise-and(0);", 1, 2, 1);
    }

    function testOpBitwiseOREvalThreeInputs() external {
        checkBadInputs("_: bitwise-and(0 0 0);", 3, 2, 3);
    }

    function testOpBitwiseOREvalZeroOutputs() external {
        checkBadOutputs(": bitwise-and(0 0);", 2, 1, 0);
    }

    function testOpBitwiseOREvalTwoOutputs() external {
        checkBadOutputs("_ _: bitwise-and(0 0);", 2, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpBitwiseOREvalBadOperand() external {
        checkUnhappyParse("_: bitwise-and<0>(0 0);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
