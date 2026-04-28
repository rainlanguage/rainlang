// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, IntegrityCheckState, OperandV2, InterpreterState, stdError} from "test/abstract/OpTest.sol";
import {LibOpUint256Div} from "../../../../../../src/lib/op/math/uint256/LibOpUint256Div.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

contract LibOpUint256DivTest is OpTest {
    /// Directly test the integrity logic of LibOpUint256Div. This tests the happy
    /// path where the inputs input and calc match.
    function testOpUint256DivIntegrityHappy(IntegrityCheckState memory state, uint8 inputs, uint16 operandData)
        external
        pure
    {
        inputs = uint8(bound(inputs, 2, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpUint256Div.integrity(state, LibOperand.build(inputs, 1, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpUint256Div. This tests the unhappy
    /// path where the operand is invalid due to 0 inputs.
    function testOpUint256DivIntegrityUnhappyZeroInputs(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpUint256Div.integrity(state, OperandV2.wrap(0));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpUint256Div. This tests the unhappy
    /// path where the operand is invalid due to 1 inputs.
    function testOpUint256DivIntegrityUnhappyOneInput(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpUint256Div.integrity(state, OperandV2.wrap(bytes32(uint256(0x010000))));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    function _testOpUint256DivRun(OperandV2 operand, StackItem[] memory inputs) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        opReferenceCheck(
            state, operand, LibOpUint256Div.referenceFn, LibOpUint256Div.integrity, LibOpUint256Div.run, inputs
        );
    }

    /// Directly test the runtime logic of LibOpUint256Div.
    function testOpUint256DivRun(StackItem[] memory inputs) external {
        vm.assume(inputs.length >= 2);
        vm.assume(inputs.length <= 0x0F);
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);

        uint256 divZeros = 0;
        for (uint256 i = 1; i < inputs.length; i++) {
            if (StackItem.unwrap(inputs[i]) == 0) {
                divZeros++;
            }
        }
        if (divZeros > 0) {
            vm.expectRevert(stdError.divisionError);
        }
        this._testOpUint256DivRun(operand, inputs);
    }

    /// Test the eval of `uint256-div` opcode parsed from a string. Tests zero inputs.
    function testOpUint256DivEvalZeroInputs() external {
        checkBadInputs("_: uint256-div();", 0, 2, 0);
    }

    /// Test the eval of `uint256-div` opcode parsed from a string. Tests one input.
    function testOpUint256DivEvalOneInput() external {
        checkBadInputs("_: uint256-div(5e-18);", 1, 2, 1);
        checkBadInputs("_: uint256-div(0e-18);", 1, 2, 1);
        checkBadInputs("_: uint256-div(1e-18);", 1, 2, 1);
        checkBadInputs("_: uint256-div(max-positive-value());", 1, 2, 1);
    }

    function testOpUint256DivEvalZeroOutputs() external {
        checkBadOutputs(": uint256-div(0 0);", 2, 1, 0);
    }

    function testOpUint256DivEvalTwoOutputs() external {
        checkBadOutputs("_ _: uint256-div(0 0);", 2, 1, 2);
    }

    /// Test the eval of `uint256-div` opcode parsed from a string. Tests two inputs.
    /// Tests the happy path where we do not divide by zero.
    /// Note that the division truncates (rounds down).
    function testOpUint256DivEval2InputsHappy() external view {
        // Show that the division truncates (rounds down).
        checkHappy("_: uint256-div(0x06 0x01);", bytes32(uint256(6)), "6 / 1");
        checkHappy("_: uint256-div(0x06 0x02);", bytes32(uint256(3)), "6 / 2");
        checkHappy("_: uint256-div(0x06 0x03);", bytes32(uint256(2)), "6 / 3");
        checkHappy("_: uint256-div(0x06 0x04);", bytes32(uint256(1)), "6 / 4");
        checkHappy("_: uint256-div(0x06 0x05);", bytes32(uint256(1)), "6 / 5");
        checkHappy("_: uint256-div(0x06 0x06);", bytes32(uint256(1)), "6 / 6");
        checkHappy("_: uint256-div(0x06 0x07);", bytes32(uint256(0)), "6 / 7");
        checkHappy("_: uint256-div(0x06 uint256-max-value());", 0, "6 / uint256-max-value()");

        // Anything divided by 1 is itself.
        checkHappy("_: uint256-div(0 0x01);", bytes32(uint256(0)), "0 / 1");
        checkHappy("_: uint256-div(0x01 0x01);", bytes32(uint256(1)), "1 / 1");
        checkHappy("_: uint256-div(0x02 0x01);", bytes32(uint256(2)), "2 / 1");
        checkHappy("_: uint256-div(0x03 0x01);", bytes32(uint256(3)), "3 / 1");
        checkHappy("_: uint256-div(uint256-max-value() 0x01);", bytes32(type(uint256).max), "uint256-max-value() / 1");

        // Anything divided by itself is 1 (except 0).
        checkHappy("_: uint256-div(0x01 0x01);", bytes32(uint256(1)), "1 / 1");
        checkHappy("_: uint256-div(0x02 0x02);", bytes32(uint256(1)), "2 / 2");
        checkHappy("_: uint256-div(0x03 0x03);", bytes32(uint256(1)), "3 / 3");
        checkHappy(
            "_: uint256-div(uint256-max-value() uint256-max-value());",
            bytes32(uint256(1)),
            "uint256-max-value() / uint256-max-value()"
        );
    }

    /// Test the eval of `uint256-div` opcode parsed from a string. Tests two inputs.
    /// Tests the unhappy path where we divide by zero.
    function testOpUint256DivEval2InputsUnhappy() external {
        checkUnhappy("_: uint256-div(0 0);", stdError.divisionError);
        checkUnhappy("_: uint256-div(0x01 0);", stdError.divisionError);
        checkUnhappy("_: uint256-div(uint256-max-value() 0);", stdError.divisionError);
    }

    /// Test the eval of `uint256-div` opcode parsed from a string. Tests three inputs.
    /// Tests the happy path where we do not divide by zero.
    function testOpUint256DivEval3InputsHappy() external view {
        // Show that the division truncates (rounds down).
        checkHappy("_: uint256-div(0x06 0x01 0x01);", bytes32(uint256(6)), "6 / 1 / 1");
        checkHappy("_: uint256-div(0x06 0x02 0x01);", bytes32(uint256(3)), "6 / 2 / 1");
        checkHappy("_: uint256-div(0x06 0x03 0x01);", bytes32(uint256(2)), "6 / 3 / 1");
        checkHappy("_: uint256-div(0x06 0x04 0x01);", bytes32(uint256(1)), "6 / 4 / 1");
        checkHappy("_: uint256-div(0x06 0x05 0x01);", bytes32(uint256(1)), "6 / 5 / 1");
        checkHappy("_: uint256-div(0x06 0x06 0x01);", bytes32(uint256(1)), "6 / 6 / 1");
        checkHappy("_: uint256-div(0x06 0x07 0x01);", 0, "6 / 7 / 1");
        checkHappy("_: uint256-div(0x06 uint256-max-value() 0x01);", 0, "6 / uint256-max-value() / 1");
        checkHappy("_: uint256-div(0x06 0x01 0x02);", bytes32(uint256(3)), "6 / 1 / 2");
        checkHappy("_: uint256-div(0x06 0x02 0x02);", bytes32(uint256(1)), "6 / 2 / 2");
        checkHappy("_: uint256-div(0x06 0x03 0x02);", bytes32(uint256(1)), "6 / 3 / 2");
        checkHappy("_: uint256-div(0x06 0x04 0x02);", bytes32(uint256(0)), "6 / 4 / 2");
        checkHappy("_: uint256-div(0x06 0x05 0x02);", 0, "6 / 5 / 2");
        checkHappy("_: uint256-div(0x06 0x06 0x02);", 0, "6 / 6 / 2");
        checkHappy("_: uint256-div(0x06 0x07 0x02);", 0, "6 / 7 / 2");
        checkHappy("_: uint256-div(0x06 uint256-max-value() 0x02);", 0, "6 / uint256-max-value() / 2");

        // Anything divided by 1 is itself.
        checkHappy("_: uint256-div(0 0x01 0x01);", 0, "0 / 1 / 1");
        checkHappy("_: uint256-div(0x01 0x01 0x01);", bytes32(uint256(1)), "1 / 1 / 1");
        checkHappy("_: uint256-div(0x02 0x01 0x01);", bytes32(uint256(2)), "2 / 1 / 1");
        checkHappy("_: uint256-div(0x03 0x01 0x01);", bytes32(uint256(3)), "3 / 1 / 1");
        checkHappy(
            "_: uint256-div(uint256-max-value() 0x01 0x01);", bytes32(type(uint256).max), "uint256-max-value() / 1 / 1"
        );

        // Anything divided by itself is 1 (except 0).
        checkHappy("_: uint256-div(0x01 0x01 0x01);", bytes32(uint256(1)), "1 / 1 / 1");
        checkHappy("_: uint256-div(0x02 0x02 0x01);", bytes32(uint256(1)), "2 / 2 / 1");
        checkHappy("_: uint256-div(0x02 0x01 0x02);", bytes32(uint256(1)), "2 / 1 / 2");
        checkHappy("_: uint256-div(0x03 0x03 0x01);", bytes32(uint256(1)), "3 / 3 / 1");
        checkHappy("_: uint256-div(0x03 0x01 0x03);", bytes32(uint256(1)), "3 / 1 / 3");
        checkHappy(
            "_: uint256-div(uint256-max-value() uint256-max-value() 0x01);",
            bytes32(uint256(1)),
            "uint256-max-value() / uint256-max-value() / 1"
        );
        checkHappy(
            "_: uint256-div(uint256-max-value() 0x01 uint256-max-value());",
            bytes32(uint256(1)),
            "uint256-max-value() / 1 / uint256-max-value()"
        );
    }

    /// Test the eval of `uint256-div` opcode parsed from a string. Tests three inputs.
    /// Tests the unhappy path where we divide by zero.
    function testOpUint256DivEval3InputsUnhappy() external {
        checkUnhappy("_: uint256-div(0 0 0);", stdError.divisionError);
        checkUnhappy("_: uint256-div(1e-18 0 0);", stdError.divisionError);
        checkUnhappy("_: uint256-div(max-positive-value() 0 0);", stdError.divisionError);
        checkUnhappy("_: uint256-div(0 1e-18 0);", stdError.divisionError);
        checkUnhappy("_: uint256-div(1e-18 1e-18 0);", stdError.divisionError);
        checkUnhappy("_: uint256-div(max-positive-value() max-positive-value() 0);", stdError.divisionError);
        checkUnhappy("_: uint256-div(0 0 1e-18);", stdError.divisionError);
        checkUnhappy("_: uint256-div(1e-18 0 1e-18);", stdError.divisionError);
        checkUnhappy("_: uint256-div(max-positive-value() 0 1e-18);", stdError.divisionError);
    }

    /// Test the eval of `uint256-div` opcode parsed from a string.
    /// Tests that operands are disallowed.
    function testOpUint256DivEvalOperandDisallowed() external {
        checkDisallowedOperand("_: uint256-div<0>(0 0 0);");
        checkDisallowedOperand("_: uint256-div<1>(0 0 0);");
        checkDisallowedOperand("_: uint256-div<2>(0 0 0);");
        checkDisallowedOperand("_: uint256-div<3 1>(0 0 0);");
    }
}
