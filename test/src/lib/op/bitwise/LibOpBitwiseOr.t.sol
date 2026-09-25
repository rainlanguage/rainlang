// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {LibOpBitwiseOr} from "../../../../../src/lib/op/bitwise/LibOpBitwiseOr.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {UnexpectedOperand} from "../../../../../src/error/ErrParse.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";

contract LibOpBitwiseOrTest is OpTest {
    /// Directly test the integrity logic of LibOpBitwiseOr. The operand's input
    /// count is honoured, floored at 2, and there is always 1 output.
    function testOpBitwiseOrIntegrity(IntegrityCheckState memory state, uint8 inputs, uint8 outputs, uint16 operandData)
        external
        pure
    {
        inputs = uint8(bound(inputs, 2, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpBitwiseOr.integrity(state, LibOperand.build(inputs, outputs, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpBitwiseOr. This tests that the
    /// opcode correctly pushes the bitwise OR onto the stack.
    function testOpBitwiseOrRun(StackItem x, StackItem y) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = x;
        inputs[1] = y;
        OperandV2 operand = LibOperand.build(2, 1, 0);
        opReferenceCheck(
            state, operand, LibOpBitwiseOr.referenceFn, LibOpBitwiseOr.integrity, LibOpBitwiseOr.run, inputs
        );
    }

    /// Test the eval of bitwise OR parsed from a string.
    function testOpBitwiseOrEval() external view {
        checkHappy("_: bitwise-or(0x00 0x00);", 0, "0 0");
        checkHappy("_: bitwise-or(0x00 0x01);", bytes32(uint256(1)), "0 1");
        checkHappy("_: bitwise-or(0x01 0x00);", bytes32(uint256(1)), "1 0");
        checkHappy("_: bitwise-or(0x01 0x01);", bytes32(uint256(1)), "1 1");
        checkHappy("_: bitwise-or(0x00 0x02);", bytes32(uint256(2)), "0 2");
        checkHappy("_: bitwise-or(0x02 0x00);", bytes32(uint256(2)), "2 0");
        checkHappy("_: bitwise-or(0x01 0x02);", bytes32(uint256(3)), "1 2");
        checkHappy("_: bitwise-or(0x02 0x01);", bytes32(uint256(3)), "2 1");
        checkHappy("_: bitwise-or(0x02 0x02);", bytes32(uint256(2)), "2 2");
        checkHappy("_: bitwise-or(0x00 0x03);", bytes32(uint256(3)), "0 3");
        checkHappy("_: bitwise-or(0x03 0x00);", bytes32(uint256(3)), "3 0");
        checkHappy("_: bitwise-or(0x01 0x03);", bytes32(uint256(3)), "1 3");
        checkHappy("_: bitwise-or(0x03 0x01);", bytes32(uint256(3)), "3 1");
        checkHappy("_: bitwise-or(0x02 0x03);", bytes32(uint256(3)), "2 3");
        checkHappy("_: bitwise-or(0x03 0x02);", bytes32(uint256(3)), "3 2");
        checkHappy("_: bitwise-or(0x03 0x03);", bytes32(uint256(3)), "3 3");
    }

    /// Test that a bitwise OR with bad inputs fails integrity.
    function testOpBitwiseOrEvalZeroInputs() external {
        checkBadInputs("_: bitwise-or();", 0, 2, 0);
    }

    function testOpBitwiseOrEvalOneInput() external {
        checkBadInputs("_: bitwise-or(0);", 1, 2, 1);
    }

    /// Three inputs fold rather than failing integrity. Derived from the
    /// fold, not observed: bitwise-or is associative and commutative, so
    /// `bitwise-or(a b c)` is `a | b | c` whatever the order.
    function testOpBitwiseOrEvalThreeInputs() external view {
        checkHappy("_: bitwise-or(0x03 0x05 0x09);", bytes32(uint256(0x03 | 0x05 | 0x09)), "");
        checkHappy("_: bitwise-or(0x0F 0x0F 0x0F);", bytes32(uint256(0x0F)), "");
    }

    function testOpBitwiseOrEvalZeroOutputs() external {
        checkBadOutputs(": bitwise-or(0 0);", 2, 1, 0);
    }

    function testOpBitwiseOrEvalTwoOutputs() external {
        checkBadOutputs("_ _: bitwise-or(0 0);", 2, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpBitwiseOrEvalBadOperand() external {
        checkUnhappyParse("_: bitwise-or<0>(0 0);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
