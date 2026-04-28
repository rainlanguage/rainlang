// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, IntegrityCheckState, InterpreterState, OperandV2} from "test/abstract/OpTest.sol";
import {LibOpDiv} from "../../../../../src/lib/op/math/LibOpDiv.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {Float, LibDecimalFloat} from "rain.math.float/lib/LibDecimalFloat.sol";
import {
    LibDecimalFloatImplementation,
    DivisionByZero
} from "rain.math.float/lib/implementation/LibDecimalFloatImplementation.sol";

contract LibOpDivTest is OpTest {
    using LibDecimalFloat for Float;

    /// Directly test the integrity logic of LibOpDiv. This tests the
    /// happy path where the inputs input and calc match.
    function testOpDivIntegrityHappy(IntegrityCheckState memory state, uint8 inputs, uint16 operandData) external pure {
        inputs = uint8(bound(inputs, 2, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) = LibOpDiv.integrity(state, LibOperand.build(inputs, 1, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpDiv. This tests the
    /// unhappy path where the operand is invalid due to 0 inputs.
    function testOpDivIntegrityUnhappyZeroInputs(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpDiv.integrity(state, OperandV2.wrap(0));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpDiv. This tests the
    /// unhappy path where the operand is invalid due to 1 inputs.
    function testOpDivIntegrityUnhappyOneInput(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpDiv.integrity(state, OperandV2.wrap(bytes32(uint256(0x110000))));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    function _testOpDivRun(OperandV2 operand, StackItem[] memory inputs) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        opReferenceCheck(state, operand, LibOpDiv.referenceFn, LibOpDiv.integrity, LibOpDiv.run, inputs);
    }

    /// Directly test the runtime logic of LibOpDiv.
    function testOpDivRun(StackItem[] memory inputs) public {
        vm.assume(inputs.length >= 2);
        vm.assume(inputs.length <= 0x0F);
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);

        (int256 signedCoefficientA, int256 exponentA) = LibDecimalFloat.unpack(Float.wrap(StackItem.unwrap(inputs[0])));

        uint256 divideByZero = 0;
        for (uint256 i = 1; i < inputs.length; i++) {
            (int256 signedCoefficientB, int256 exponentB) =
                LibDecimalFloat.unpack(Float.wrap(StackItem.unwrap(inputs[i])));
            if (signedCoefficientB == 0) {
                divideByZero++;
                break;
            }

            (signedCoefficientA, exponentA) =
                LibDecimalFloatImplementation.div(signedCoefficientA, exponentA, signedCoefficientB, exponentB);
        }
        // Truncation is intentional here to check overflows.
        //forge-lint: disable-next-line(unsafe-typecast)
        if (int32(exponentA) != exponentA && exponentA > 0) {
            vm.expectRevert();
        } else if (divideByZero > 0) {
            vm.expectRevert();
        }
        this._testOpDivRun(operand, inputs);
    }

    function testDebugOpDivRun() external {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(115792089237316195423570985008687907853269984665640564039458)));
        testOpDivRun(inputs);
    }

    /// Test the eval of `div` opcode parsed from a string.
    /// Tests zero inputs.
    function testOpDivEvalZeroInputs() external {
        checkBadInputs("_: div();", 0, 2, 0);
    }

    /// Test the eval of `div` opcode parsed from a string.
    /// Tests one input.
    function testOpDivEvalOneInput() external {
        checkBadInputs("_: div(5);", 1, 2, 1);
        checkBadInputs("_: div(0);", 1, 2, 1);
        checkBadInputs("_: div(1);", 1, 2, 1);
        checkBadInputs("_: div(max-positive-value());", 1, 2, 1);
    }

    /// Test the eval of `div` opcode parsed from a string.
    /// Tests two inputs.
    /// Tests the happy path where we do not divide by zero or overflow.
    function testOpDivEvalTwoInputsHappy() external view {
        checkHappy("_: div(0 1);", Float.unwrap(LibDecimalFloat.packLossless(0, 0)), "0 1");
        checkHappy("_: div(1 1);", Float.unwrap(LibDecimalFloat.packLossless(1e67, -67)), "1 1");
        checkHappy("_: div(1 2);", Float.unwrap(LibDecimalFloat.packLossless(0.5e67, -67)), "1 2");
        checkHappy("_: div(2 1);", Float.unwrap(LibDecimalFloat.packLossless(2e66, -66)), "2 1");
        checkHappy("_: div(2 2);", Float.unwrap(LibDecimalFloat.packLossless(1e67, -67)), "2 2");
        checkHappy("_: div(2 0.1);", Float.unwrap(LibDecimalFloat.packLossless(20e65, -65)), "2 0.1");
        checkHappy(
            "_: div(max-positive-value() 1);",
            Float.unwrap(LibDecimalFloat.FLOAT_MAX_POSITIVE_VALUE),
            "max-positive-value() 1"
        );
    }

    /// Test the eval of `div` opcode parsed from a string.
    /// Tests two inputs.
    /// Tests the unhappy path where we divide by zero.
    function testOpDivEvalTwoInputsUnhappyDivZero() external {
        checkUnhappy("_: div(0 0);", abi.encodeWithSelector(DivisionByZero.selector, 0, 0));
        checkUnhappy("_: div(1 0);", abi.encodeWithSelector(DivisionByZero.selector, 1, 0));
        checkUnhappy(
            "_: div(max-positive-value() 0);",
            abi.encodeWithSelector(DivisionByZero.selector, type(int224).max, type(int32).max)
        );
    }

    /// Test the eval of `div` opcode parsed from a string.
    /// Tests two inputs.
    /// Tests the unhappy path where the final result overflows.
    function testOpDivEvalTwoInputsUnhappyOverflow() external {
        checkUnhappyOverflow(
            "_: div(max-positive-value() 1e-18);",
            13479973333575319897333507543509815336818572211270286240551805124607000000000,
            2147483656
        );
    }

    /// Test the eval of `div` opcode parsed from a string.
    /// Tests three inputs.
    /// Tests the happy path where we do not divide by zero or overflow.
    function testOpDivEvalThreeInputsHappy() external view {
        checkHappy("_: div(0 1 1);", Float.unwrap(LibDecimalFloat.packLossless(0, 0)), "0 1 1");
        checkHappy("_: div(1 1 1);", Float.unwrap(LibDecimalFloat.packLossless(1e67, -67)), "1 1 1");
        checkHappy("_: div(1 1 2);", Float.unwrap(LibDecimalFloat.packLossless(5e66, -67)), "1 1 2");
        checkHappy("_: div(1 2 1);", Float.unwrap(LibDecimalFloat.packLossless(5e66, -67)), "1 2 1");
        checkHappy("_: div(1 2 2);", Float.unwrap(LibDecimalFloat.packLossless(0.25e67, -67)), "1 2 2");
        checkHappy("_: div(1 2 0.1);", Float.unwrap(LibDecimalFloat.packLossless(5e66, -66)), "1 2 0.1");
        checkHappy(
            "_: div(max-positive-value() 1 1);",
            Float.unwrap(LibDecimalFloat.FLOAT_MAX_POSITIVE_VALUE),
            "max-positive-value() 1 1"
        );
    }

    /// Test the eval of `div` opcode parsed from a string.
    /// Tests three inputs.
    /// Tests the unhappy path where we divide by zero.
    function testOpDivEvalThreeInputsUnhappyExamples() external {
        checkUnhappy("_: div(0 0 0);", abi.encodeWithSelector(DivisionByZero.selector, 0, 0));
        checkUnhappy("_: div(1 0 0);", abi.encodeWithSelector(DivisionByZero.selector, 1, 0));
        checkUnhappy("_: div(1 1 0);", abi.encodeWithSelector(DivisionByZero.selector, 1e76, -76));
        checkUnhappy(
            "_: div(max-positive-value() 0 0);",
            abi.encodeWithSelector(DivisionByZero.selector, type(int224).max, type(int32).max)
        );
    }

    /// Test the eval of `div` opcode parsed from a string.
    /// Tests three inputs.
    /// Tests the unhappy path where the final result overflows.
    function testOpDivEvalThreeInputsUnhappyOverflow() external {
        checkUnhappyOverflow(
            "_: div(max-positive-value() 1e-18 1e-18);",
            13479973333575319897333507543509815336818572211270286240551805124607000000000,
            2147483674
        );
        // checkUnhappyOverflow("_: div(1e900000000 1 1e-900000000);", 1, -8000000000000000000000000000);
        //         checkUnhappy("_: div(1e52 1e-8 1);", abi.encodeWithSelector(PRBMath_MulDiv_Overflow.selector, 1e70, 1e18, 1e10));
    }

    /// Test the eval of `div` opcode parsed from a string.
    /// Tests that operands are disallowed.
    function testOpDivEvalOperandsDisallowed() external {
        checkDisallowedOperand("_: div<0>(1 1 1);");
        checkDisallowedOperand("_: div<1>(1 1 1);");
        checkDisallowedOperand("_: div<2>(1 1 1);");
        checkDisallowedOperand("_: div<0 0>(1 1 1);");
        checkDisallowedOperand("_: div<0 1>(1 1 1);");
        checkDisallowedOperand("_: div<1 0>(1 1 1);");
    }

    function testOpDivEvalZeroOutputs() external {
        checkBadOutputs(": div(0 1);", 2, 1, 0);
    }

    function testOpDivEvalTwoOutputs() external {
        checkBadOutputs("_ _: div(0 1);", 2, 1, 2);
    }
}
