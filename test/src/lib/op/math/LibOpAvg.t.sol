// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, IntegrityCheckState, OperandV2, InterpreterState, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpAvg} from "../../../../../src/lib/op/math/LibOpAvg.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

contract LibOpAvgTest is OpTest {
    /// Directly test the integrity logic of LibOpAvg.
    /// Inputs are always 2, outputs are always 1.
    function testOpAvgIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpAvg.integrity(state, operand);
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpAvg.
    function testOpAvgRun(
        int256 signedCoefficientA,
        int256 exponentA,
        int256 signedCoefficientB,
        int256 exponentB,
        uint16 operandData
    ) public view {
        signedCoefficientA = bound(signedCoefficientA, type(int224).min, type(int224).max);
        signedCoefficientB = bound(signedCoefficientB, type(int224).min, type(int224).max);
        exponentA = bound(exponentA, type(int24).min, type(int24).max);
        exponentB = bound(exponentB, type(int24).min, type(int24).max);

        Float a = LibDecimalFloat.packLossless(signedCoefficientA, exponentA);
        Float b = LibDecimalFloat.packLossless(signedCoefficientB, exponentB);
        InterpreterState memory state = opTestDefaultInterpreterState();

        OperandV2 operand = LibOperand.build(2, 1, operandData);
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(Float.unwrap(a));
        inputs[1] = StackItem.wrap(Float.unwrap(b));

        opReferenceCheck(state, operand, LibOpAvg.referenceFn, LibOpAvg.integrity, LibOpAvg.run, inputs);
    }

    /// Test the eval of `avg`.
    function testOpAvgEvalExamples() external view {
        checkHappy("_: avg(0 0);", Float.unwrap(LibDecimalFloat.packLossless(0, 0)), "0 0");
        checkHappy("_: avg(0 1);", Float.unwrap(LibDecimalFloat.packLossless(5e66, -67)), "0 1");
        checkHappy("_: avg(1 0);", Float.unwrap(LibDecimalFloat.packLossless(5e66, -67)), "1 0");
        checkHappy("_: avg(1 1);", Float.unwrap(LibDecimalFloat.packLossless(1e67, -67)), "1 1");
        checkHappy("_: avg(1 2);", Float.unwrap(LibDecimalFloat.packLossless(1.5e66, -66)), "1 2");
        checkHappy("_: avg(2 2);", Float.unwrap(LibDecimalFloat.packLossless(2e66, -66)), "2 2");
        checkHappy("_: avg(2 3);", Float.unwrap(LibDecimalFloat.packLossless(2.5e66, -66)), "2 3");
        checkHappy("_: avg(2 4);", Float.unwrap(LibDecimalFloat.packLossless(3e66, -66)), "2 4");
        checkHappy("_: avg(4 0.5);", Float.unwrap(LibDecimalFloat.packLossless(2.25e66, -66)), "4 5");
    }

    /// Test the eval of `avg` for bad inputs.
    function testOpAvgEvalOneInput() external {
        checkBadInputs("_: avg(1);", 1, 2, 1);
    }

    function testOpAvgEvalThreeInputs() external {
        checkBadInputs("_: avg(1 1 1);", 3, 2, 3);
    }

    function testOpAvgEvalZeroOutputs() external {
        checkBadOutputs(": avg(0 0);", 2, 1, 0);
    }

    function testOpAvgEvalTwoOutputs() external {
        checkBadOutputs("_ _: avg(0 0);", 2, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpAvgEvalOperandDisallowed() external {
        checkUnhappyParse("_: avg<0>(1 1);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
