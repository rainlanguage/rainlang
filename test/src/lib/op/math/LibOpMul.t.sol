// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {console2} from "forge-std/Test.sol";
import {LibOpMul} from "../../../../../src/lib/op/math/LibOpMul.sol";
import {OpTest, IntegrityCheckState, OperandV2} from "test/abstract/OpTest.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {Float, LibDecimalFloat} from "rain.math.float/lib/LibDecimalFloat.sol";
import {ExponentOverflow, CoefficientOverflow} from "rain.math.float/error/ErrDecimalFloat.sol";

contract LibOpMulTest is OpTest {
    /// Directly test the integrity logic of LibOpMul. This tests the
    /// happy path where the inputs input and calc match.
    function testOpMulIntegrityHappy(IntegrityCheckState memory state, uint8 inputs, uint16 operandData) external pure {
        inputs = uint8(bound(inputs, 2, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) = LibOpMul.integrity(state, LibOperand.build(inputs, 1, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpMul. This tests the
    /// unhappy path where the operand is invalid due to 0 inputs.
    function testOpMulIntegrityUnhappyZeroInputs(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpMul.integrity(state, OperandV2.wrap(0));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpMul. This tests the
    /// unhappy path where the operand is invalid due to 1 inputs.
    function testOpDecimal18MulIntegrityUnhappyOneInput(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpMul.integrity(state, OperandV2.wrap(bytes32(uint256(0x010000))));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    function _testOpMulRun(OperandV2 operand, StackItem[] memory inputs) external view {
        opReferenceCheck(
            opTestDefaultInterpreterState(), operand, LibOpMul.referenceFn, LibOpMul.integrity, LibOpMul.run, inputs
        );
    }

    /// Directly test the runtime logic of LibOpMul.
    function testOpMulRun(StackItem[] memory inputs) public view {
        vm.assume(inputs.length >= 2);
        vm.assume(inputs.length <= 0x0F);
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);

        try this._testOpMulRun(operand, inputs) {}
        catch (bytes memory err) {
            console2.logBytes(err);
            // Truncation is intentional so that we can read out the selector
            // separate from the overall error.
            //forge-lint: disable-next-line(unsafe-typecast)
            assertTrue(bytes4(err) == CoefficientOverflow.selector || bytes4(err) == ExponentOverflow.selector);
        }
    }

    /// Test the eval of `mul` opcode parsed from a string.
    /// Tests zero inputs.
    function testOpMulEvalZeroInputs() external {
        checkBadInputs("_: mul();", 0, 2, 0);
    }

    /// Test the eval of `mul` opcode parsed from a string.
    /// Tests one input.
    function testOpMulEvalOneInput() external {
        checkBadInputs("_: mul(5);", 1, 2, 1);
        checkBadInputs("_: mul(0);", 1, 2, 1);
        checkBadInputs("_: mul(1);", 1, 2, 1);
        checkBadInputs("_: mul(max-positive-value());", 1, 2, 1);
    }

    function testOpMulZeroOutputs() external {
        checkBadOutputs(": mul(0 0);", 2, 1, 0);
    }

    function testOpMulTwoOutputs() external {
        checkBadOutputs("_ _: mul(0 0);", 2, 1, 2);
    }

    /// Test the eval of `mul` opcode parsed from a string.
    /// Tests two inputs.
    /// Tests the happy path where we do not overflow.
    function testOpMulEvalTwoInputsHappy() external view {
        checkHappy("_: mul(0 1);", Float.unwrap(LibDecimalFloat.packLossless(0, 0)), "0 1");
        checkHappy("_: mul(1 1);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "1 1");
        checkHappy("_: mul(1 2);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "1 2");
        checkHappy("_: mul(2 1);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "2 1");
        checkHappy("_: mul(2 2);", Float.unwrap(LibDecimalFloat.packLossless(4, 0)), "2 2");
        checkHappy("_: mul(2 0.1);", Float.unwrap(LibDecimalFloat.packLossless(2, -1)), "2 0.1");
        checkHappy("_: mul(1 0.1);", Float.unwrap(LibDecimalFloat.packLossless(1, -1)), "1 0.1");
        checkHappy("_: mul(1 0.01);", Float.unwrap(LibDecimalFloat.packLossless(1, -2)), "1 0.01");
        checkHappy("_: mul(0.001 0.001);", Float.unwrap(LibDecimalFloat.packLossless(1, -6)), "0.001 0.001");
        checkHappy("_: mul(10 10);", Float.unwrap(LibDecimalFloat.packLossless(100, 0)), "10 10");
        // Test an intermediate overflow.
        checkHappy(
            "_: mul(1 max-positive-value());",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "1 max-positive-value()"
        );
    }

    /// Test the eval of `mul` opcode parsed from a string.
    /// Tests two inputs.
    /// Tests the unhappy path where the final result overflows.
    function testOpMulEvalTwoInputsUnhappyOverflow() external {
        checkUnhappyOverflow(
            "_: mul(max-positive-value() 10);",
            134799733335753198973335075435098153368185722112702862405518051246070,
            2147483647
        );
    }

    /// Test the eval of `mul` opcode parsed from a string.
    /// Tests three inputs.
    /// Tests the happy path where we do not divide by zero or overflow.
    function testOpMulEvalThreeInputsHappy() external view {
        checkHappy("_: mul(0 0 0);", Float.unwrap(LibDecimalFloat.packLossless(0, 0)), "0 0 0");
        checkHappy("_: mul(1 0 0);", Float.unwrap(LibDecimalFloat.packLossless(0, 0)), "1 0 0");
        checkHappy("_: mul(1 1 0);", Float.unwrap(LibDecimalFloat.packLossless(0, 0)), "1 1 0");
        checkHappy("_: mul(1 1 1);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "1 1 1");
        checkHappy("_: mul(1 1 2);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "1 1 2");
        checkHappy("_: mul(1 2 1);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "1 2 1");
        checkHappy("_: mul(2 1 1);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "2 1 1");
        checkHappy("_: mul(2 2 2);", Float.unwrap(LibDecimalFloat.packLossless(8, 0)), "2 2 2");
        checkHappy("_: mul(2 0.1 1);", Float.unwrap(LibDecimalFloat.packLossless(2, -1)), "2 0.1 1");
        checkHappy("_: mul(1 0.1 1);", Float.unwrap(LibDecimalFloat.packLossless(1, -1)), "1 0.1 1");
        checkHappy("_: mul(1 0.01 1);", Float.unwrap(LibDecimalFloat.packLossless(1, -2)), "1 0.01 1");
        checkHappy("_: mul(0.001 0.001 0.001);", Float.unwrap(LibDecimalFloat.packLossless(1, -9)), "0.001 0.001 0.001");
        checkHappy("_: mul(10 10 10);", Float.unwrap(LibDecimalFloat.packLossless(1000, 0)), "10 10 10");
        // Test an intermediate overflow.
        checkHappy(
            "_: mul(1 max-positive-value() 1);",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "1 max-positive-value() 1"
        );
    }

    /// Test the eval of `mul` opcode parsed from a string.
    /// Tests three inputs.
    /// Tests the unhappy path where the final result overflows.
    function testOpMulEvalThreeInputsUnhappyOverflow() external {
        checkUnhappyOverflow(
            "_: mul(max-positive-value() 1 10);",
            134799733335753198973335075435098153368185722112702862405518051246070,
            2147483647
        );
    }

    /// Test the eval of `mul` opcode parsed from a string.
    /// Tests that operands are disallowed.
    function testOpMulEvalOperandsDisallowed() external {
        checkDisallowedOperand("_: mul<0>(1 1 1);");
        checkDisallowedOperand("_: mul<1>(1 1 1);");
        checkDisallowedOperand("_: mul<2>(1 1 1);");
        checkDisallowedOperand("_: mul<0 0>(1 1 1);");
        checkDisallowedOperand("_: mul<0 1>(1 1 1);");
        checkDisallowedOperand("_: mul<1 0>(1 1 1);");
    }
}
