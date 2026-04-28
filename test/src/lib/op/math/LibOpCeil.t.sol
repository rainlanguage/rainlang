// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, IntegrityCheckState, OperandV2, InterpreterState, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpCeil} from "../../../../../src/lib/op/math/LibOpCeil.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

contract LibOpCeilTest is OpTest {
    /// Directly test the integrity logic of LibOpCeil.
    /// Inputs are always 1, outputs are always 1.
    function testOpCeilIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpCeil.integrity(state, operand);
        assertEq(calcInputs, 1);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpCeil.
    function testOpCeilRun(Float a, uint16 operandData) public view {
        InterpreterState memory state = opTestDefaultInterpreterState();

        OperandV2 operand = LibOperand.build(1, 1, operandData);
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = StackItem.wrap(Float.unwrap(a));

        opReferenceCheck(state, operand, LibOpCeil.referenceFn, LibOpCeil.integrity, LibOpCeil.run, inputs);
    }

    /// Test the eval of `ceil`.
    function testOpCeilEval() external view {
        checkHappy("_: ceil(0);", 0, "0");
        checkHappy("_: ceil(1);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "1");
        checkHappy("_: ceil(0.5);", Float.unwrap(LibDecimalFloat.packLossless(1e67, -67)), "0.5");
        checkHappy("_: ceil(2);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "2");
        checkHappy("_: ceil(2.5);", Float.unwrap(LibDecimalFloat.packLossless(3e66, -66)), "2.5");

        checkHappy("_: ceil(-1);", Float.unwrap(LibDecimalFloat.packLossless(-1, 0)), "-1");
        checkHappy("_: ceil(-1.1);", Float.unwrap(LibDecimalFloat.packLossless(-10, -1)), "-1.1");
        checkHappy("_: ceil(-0.5);", Float.unwrap(LibDecimalFloat.packLossless(0, -1)), "-0.5");
        checkHappy("_: ceil(-1.5);", Float.unwrap(LibDecimalFloat.packLossless(-10, -1)), "-1.5");
        checkHappy("_: ceil(-2);", Float.unwrap(LibDecimalFloat.packLossless(-2, 0)), "-2");
        checkHappy("_: ceil(-2.5);", Float.unwrap(LibDecimalFloat.packLossless(-20, -1)), "-2.5");

        checkHappy(
            "_: ceil(max-positive-value());",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "max-positive-value"
        );
        checkHappy(
            "_: ceil(min-negative-value());",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).min, type(int32).max)),
            "min-negative-value"
        );
    }

    /// Test the eval of `ceil` for bad inputs.
    function testOpCeilZeroInputs() external {
        checkBadInputs("_: ceil();", 0, 1, 0);
    }

    function testOpCeilTwoInputs() external {
        checkBadInputs("_: ceil(1 1);", 2, 1, 2);
    }

    function testOpCeilZeroOutputs() external {
        checkBadOutputs(": ceil(1);", 1, 1, 0);
    }

    function testOpCeilTwoOutputs() external {
        checkBadOutputs("_ _: ceil(1);", 1, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpCeilEvalOperandDisallowed() external {
        checkUnhappyParse("_: ceil<0>(1);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
