// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, IntegrityCheckState, OperandV2, InterpreterState, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpLinearGrowth} from "../../../../../../src/lib/op/math/growth/LibOpLinearGrowth.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {Float, LibDecimalFloat} from "rain.math.float/lib/LibDecimalFloat.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

contract LibOpLinearGrowthTest is OpTest {
    /// Directly test the integrity logic of LibOpLinearGrowth.
    /// Inputs are always 3, outputs are always 1.
    function testOpLinearGrowthIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpLinearGrowth.integrity(state, operand);
        assertEq(calcInputs, 3);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpLinearGrowth.
    function testOpLinearGrowthRun(
        int224 signedCoefficientA,
        int32 exponentA,
        int224 signedCoefficientR,
        int32 exponentR,
        int224 signedCoefficientT,
        int32 exponentT,
        uint16 operandData
    ) public view {
        exponentA = int32(bound(exponentA, type(int24).min, type(int24).max));
        Float a = LibDecimalFloat.packLossless(signedCoefficientA, exponentA);

        exponentR = int32(bound(exponentR, type(int24).min, type(int24).max));
        Float r = LibDecimalFloat.packLossless(signedCoefficientR, exponentR);

        exponentT = int32(bound(exponentT, type(int24).min, type(int24).max));
        Float t = LibDecimalFloat.packLossless(signedCoefficientT, exponentT);

        InterpreterState memory state = opTestDefaultInterpreterState();

        OperandV2 operand = LibOperand.build(3, 1, operandData);
        StackItem[] memory inputs = new StackItem[](3);
        inputs[0] = StackItem.wrap(Float.unwrap(a));
        inputs[1] = StackItem.wrap(Float.unwrap(r));
        inputs[2] = StackItem.wrap(Float.unwrap(t));

        opReferenceCheck(
            state, operand, LibOpLinearGrowth.referenceFn, LibOpLinearGrowth.integrity, LibOpLinearGrowth.run, inputs
        );
    }

    /// Test the eval of `linear-growth`.
    function testOpLinearGrowthEval() external view {
        checkHappy("_: linear-growth(0 0 0);", 0, "0 0 0");
        checkHappy("_: linear-growth(0 0.1 0);", 0, "0 0.1 0");
        checkHappy("_: linear-growth(0 0.1 1);", Float.unwrap(LibDecimalFloat.packLossless(1, -1)), "0 0.1 1");
        checkHappy("_: linear-growth(1 0.1 0);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "1 0.1 0");
        checkHappy("_: linear-growth(1 0.1 1);", Float.unwrap(LibDecimalFloat.packLossless(1.1e67, -67)), "1 0.1 1");
        checkHappy("_: linear-growth(1 0.1 2);", Float.unwrap(LibDecimalFloat.packLossless(1.2e67, -67)), "1 0.1 2");
        checkHappy(
            "_: linear-growth(1 0.1 2.5);", Float.unwrap(LibDecimalFloat.packLossless(1.25e67, -67)), "1 0.1 2.5"
        );
        checkHappy("_: linear-growth(1 0 2);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "1 0 2");
        checkHappy(
            "_: linear-growth(1 0.1 0.5);", Float.unwrap(LibDecimalFloat.packLossless(1.05e67, -67)), "1 0.1 0.5"
        );
        checkHappy("_: linear-growth(2 0.1 0);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "2 0.1 0");
        checkHappy("_: linear-growth(2 0.1 1);", Float.unwrap(LibDecimalFloat.packLossless(2.1e66, -66)), "2 0.1 1");
        checkHappy("_: linear-growth(2 0.1 2);", Float.unwrap(LibDecimalFloat.packLossless(2.2e66, -66)), "2 0.1 2");

        checkHappy("_: linear-growth(1 -0.1 1);", Float.unwrap(LibDecimalFloat.packLossless(0.9e67, -67)), "1 -0.1 1");
        checkHappy(
            "_: linear-growth(-1 -0.1 2);", Float.unwrap(LibDecimalFloat.packLossless(-1.2e67, -67)), "-1 -0.1 2"
        );
    }

    function testOpLinearGrowthEvalZeroInputs() external {
        checkBadInputs(": linear-growth();", 0, 3, 0);
    }

    function testOpLinearGrowthEvalOneInput() external {
        checkBadInputs("_: linear-growth(1);", 1, 3, 1);
    }

    function testOpLinearGrowthEvalTwoInputs() external {
        checkBadInputs("_: linear-growth(1 0);", 2, 3, 2);
    }

    function testOpLinearGrowthEvalFourInputs() external {
        checkBadInputs("_: linear-growth(1 0 0 1);", 4, 3, 4);
    }

    function testOpLinearGrowthEvalZeroOutputs() external {
        checkBadOutputs(": linear-growth(1 0 0);", 3, 1, 0);
    }

    function testOpLinearGrowthEvalTwoOutputs() external {
        checkBadOutputs("_ _: linear-growth(1 0 0);", 3, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpLinearGrowthEvalOperandDisallowed() external {
        checkUnhappyParse("_: linear-growth<0>(1 0 0);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
