// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, IntegrityCheckState, OperandV2} from "test/abstract/OpTest.sol";
import {UnexpectedOperandValue, UnexpectedOperand} from "../../../../../src/error/ErrParse.sol";
import {LibOpSub} from "../../../../../src/lib/op/math/LibOpSub.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {Float, LibDecimalFloat} from "rain.math.float/lib/LibDecimalFloat.sol";

contract LibOpSubTest is OpTest {
    /// Directly test the integrity logic of LibOpSub. This tests the happy
    /// path where the inputs input and calc match.
    function testOpSubIntegrityHappy(IntegrityCheckState memory state, uint8 inputs, uint16 operandData) external pure {
        inputs = uint8(bound(inputs, 2, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) = LibOpSub.integrity(state, LibOperand.build(inputs, 1, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpSub. This tests the unhappy
    /// path where the operand is invalid due to 0 inputs.
    function testOpSubIntegrityUnhappyZeroInputs(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpSub.integrity(state, OperandV2.wrap(0));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpSub. This tests the unhappy
    /// path where the operand is invalid due to 1 inputs.
    function testOpSubIntegrityUnhappyOneInput(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpSub.integrity(state, OperandV2.wrap(bytes32(uint256(0x010000))));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpSub.
    function testOpSubRun(StackItem[] memory inputs) external view {
        vm.assume(inputs.length >= 2);
        vm.assume(inputs.length <= 0x0F);
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);

        for (uint256 i = 0; i < inputs.length; i++) {
            (int256 signedCoefficient, int256 exponent) =
                LibDecimalFloat.unpack(Float.wrap(StackItem.unwrap(inputs[i])));
            exponent = int256(bound(exponent, type(int32).min, type(int32).max / 2));
            // Bound makes typecast safe.
            //forge-lint: disable-next-line(unsafe-typecast)
            inputs[i] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(signedCoefficient, int32(exponent))));
        }

        opReferenceCheck(
            opTestDefaultInterpreterState(), operand, LibOpSub.referenceFn, LibOpSub.integrity, LibOpSub.run, inputs
        );
    }

    /// Test the eval of `sub` opcode parsed from a string. Tests zero inputs.
    function testOpSubEvalZeroInputs() external {
        checkBadInputs("_: sub();", 0, 2, 0);
    }

    /// Test the eval of `sub` opcode parsed from a string. Tests one input.
    function testOpSubEvalOneInput() external {
        checkBadInputs("_: sub(5e-18);", 1, 2, 1);
        checkBadInputs("_: sub(0);", 1, 2, 1);
        checkBadInputs("_: sub(1e-18);", 1, 2, 1);
        checkBadInputs("_: sub(max-positive-value());", 1, 2, 1);
    }

    /// Test the eval of `sub` opcode parsed from a string. Tests two inputs.
    function testOpSubEvalTwoInputs() external view {
        checkHappy("_: sub(1 0);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "1 0");
        checkHappy("_: sub(1 1);", Float.unwrap(LibDecimalFloat.packLossless(0, -76)), "1 1");
        checkHappy("_: sub(2 1);", Float.unwrap(LibDecimalFloat.packLossless(1e67, -67)), "2 1");
        checkHappy("_: sub(2 2);", Float.unwrap(LibDecimalFloat.packLossless(0, -76)), "2 2");
        checkHappy(
            "_: sub(max-positive-value() 0);",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "max-positive-value() 0"
        );
        checkHappy("_: sub(1 2);", Float.unwrap(LibDecimalFloat.packLossless(-1e67, -67)), "1 2");
        checkHappy("_: sub(1 0.1);", Float.unwrap(LibDecimalFloat.packLossless(9e66, -67)), "1 0.1");

        // Subtracting 1 from max value is still max value because floats.
        checkHappy(
            "_: sub(max-positive-value() 1);",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "max-positive-value() 1"
        );
        checkHappy(
            "_: sub(max-positive-value() max-positive-value());",
            Float.unwrap(LibDecimalFloat.packLossless(0, type(int32).max - 9)),
            "max-positive-value() max-positive-value()"
        );
    }

    /// Test the eval of `sub` opcode parsed from a string. Tests three inputs.
    function testOpSubEvalThreeInputs() external view {
        checkHappy("_: sub(1 0 0);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "1 0 0");
        checkHappy("_: sub(1 1 0);", Float.unwrap(LibDecimalFloat.packLossless(0, 0)), "1 1 0");
        checkHappy("_: sub(2 1 1);", Float.unwrap(LibDecimalFloat.packLossless(0, -76)), "2 1 1");
        checkHappy("_: sub(2 2 0);", Float.unwrap(LibDecimalFloat.packLossless(0, 0)), "2 2 0");
    }

    function testOpSubZeroOutputs() external {
        checkBadOutputs(": sub(1 1);", 2, 1, 0);
    }

    function testOpSubTwoOutputs() external {
        checkBadOutputs("_ _: sub(1 1);", 2, 1, 2);
    }

    function testOpSubEvalOperandDisallowed() external {
        checkDisallowedOperand("_: sub<0>(1 1);");
        checkDisallowedOperand("_: sub<1>(1 1);");
        checkDisallowedOperand("_: sub<2>(1 1);");
        checkDisallowedOperand("_: sub<0 0>(1 1);");
        checkDisallowedOperand("_: sub<0 1>(1 1);");
        checkDisallowedOperand("_: sub<1 0>(1 1);");
    }
}
