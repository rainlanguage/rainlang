// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, IntegrityCheckState, OperandV2, InterpreterState, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpExponentialGrowth} from "../../../../../../src/lib/op/math/growth/LibOpExponentialGrowth.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibDecimalFloat, Float} from "rain-math-float-0.3.10/src/lib/LibDecimalFloat.sol";
import {StackItem} from "../../../../../../src/interface/IInterpreterV4.sol";

contract LibOpExponentialGrowthTest is OpTest {
    /// Directly test the integrity logic of LibOpExponentialGrowth.
    /// Inputs are always 3, outputs are always 1.
    function testOpExponentialGrowthIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpExponentialGrowth.integrity(state, operand);
        assertEq(calcInputs, 3);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpExponentialGrowth.
    function testOpExponentialGrowthRun(
        int224 signedCoefficientA,
        int32 exponentA,
        int224 signedCoefficientR,
        int32 exponentR,
        int224 signedCoefficientT,
        int32 exponentT,
        uint16 operandData
    ) public view {
        signedCoefficientA = int224(bound(signedCoefficientA, 0, type(int8).max));
        exponentA = int32(bound(exponentA, -10, 10));
        Float a = LibDecimalFloat.packLossless(signedCoefficientA, exponentA);

        signedCoefficientR = int224(bound(signedCoefficientR, 0, type(int8).max));
        exponentR = int32(bound(exponentR, -10, 10));
        Float r = LibDecimalFloat.packLossless(signedCoefficientR, exponentR);

        signedCoefficientT = int224(bound(signedCoefficientT, 0, type(int8).max));
        exponentT = int32(bound(exponentT, -10, 5));
        Float t = LibDecimalFloat.packLossless(signedCoefficientT, exponentT);

        InterpreterState memory state = opTestDefaultInterpreterState();

        OperandV2 operand = LibOperand.build(3, 1, operandData);
        StackItem[] memory inputs = new StackItem[](3);
        inputs[0] = StackItem.wrap(Float.unwrap(a));
        inputs[1] = StackItem.wrap(Float.unwrap(r));
        inputs[2] = StackItem.wrap(Float.unwrap(t));

        opReferenceCheck(
            state,
            operand,
            LibOpExponentialGrowth.referenceFn,
            LibOpExponentialGrowth.integrity,
            LibOpExponentialGrowth.run,
            inputs
        );
    }

    /// Test the eval of `exponential-growth`.
    function testOpExponentialGrowthEval() external view {
        checkHappy("_: exponential-growth(0 0 0);", 0, "0 0 0");
        checkHappy("_: exponential-growth(0 0.1 0);", 0, "0 0.1 0");
        checkHappy("_: exponential-growth(0 0.1 1);", 0, "0 0.1 1");
        checkHappy("_: exponential-growth(1 0.1 0);", Float.unwrap(LibDecimalFloat.FLOAT_ONE), "1 0.1 0");
        checkHappy(
            "_: exponential-growth(1 0.1 1);", Float.unwrap(LibDecimalFloat.packLossless(1.1e40, -40)), "1 0.1 1"
        );
        // Exactly 1.21
        checkHappy(
            "_: exponential-growth(1 0.1 2);", Float.unwrap(LibDecimalFloat.packLossless(1.21e40, -40)), "1 0.1 2"
        );
        // 1.1^2.5 = 1.21 sqrt(1.1), rounded to 41 significant digits.
        checkHappy(
            "_: exponential-growth(1 0.1 2.5);",
            Float.unwrap(LibDecimalFloat.packLossless(12690587062858833718596587515527244941551, -40)),
            "1 0.1 2.5"
        );
        checkHappy("_: exponential-growth(1 0 2);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "1 0 2");
        // sqrt(1.1), rounded to 41 significant digits.
        checkHappy(
            "_: exponential-growth(1 0.1 0.5);",
            Float.unwrap(LibDecimalFloat.packLossless(10488088481701515469914535136799375984753, -40)),
            "1 0.1 0.5"
        );
        checkHappy("_: exponential-growth(2 0.1 0);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "2 0.1 0");
        checkHappy(
            "_: exponential-growth(2 0.1 1);", Float.unwrap(LibDecimalFloat.packLossless(2.2e40, -40)), "2 0.1 1"
        );
        checkHappy(
            "_: exponential-growth(2 0.1 2);", Float.unwrap(LibDecimalFloat.packLossless(2.42e40, -40)), "2 0.1 2"
        );

        /// 2 times 1/1.1 rounded to 41 significant digits; the product by 2 is exact.
        checkHappy(
            "_: exponential-growth(2 0.1 -1);",
            Float.unwrap(LibDecimalFloat.packLossless(181818181818181818181818181818181818181818, -41)),
            "2 0.1 -1"
        );
    }

    function testOpExponentialGrowthEvalZeroInputs() external {
        checkBadInputs(": exponential-growth();", 0, 3, 0);
    }

    function testOpExponentialGrowthEvalOneInput() external {
        checkBadInputs("_: exponential-growth(1);", 1, 3, 1);
    }

    function testOpExponentialGrowthEvalTwoInputs() external {
        checkBadInputs("_: exponential-growth(1 0);", 2, 3, 2);
    }

    function testOpExponentialGrowthEvalFourInputs() external {
        checkBadInputs("_: exponential-growth(1 0 0 1);", 4, 3, 4);
    }

    function testOpExponentialGrowthEvalZeroOutputs() external {
        checkBadOutputs(": exponential-growth(1 0 0);", 3, 1, 0);
    }

    function testOpExponentialGrowthEvalTwoOutputs() external {
        checkBadOutputs("_ _: exponential-growth(1 0 0);", 3, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpExponentialGrowthEvalOperandDisallowed() external {
        checkUnhappyParse("_: exponential-growth<0>(1 0 0);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }

    function externalRun(StackItem[] memory inputs) external view returns (StackItem[] memory) {
        return opRunOutputs(LibOperand.build(3, 1, 0), LibOpExponentialGrowth.run, inputs);
    }

    function externalReference(StackItem[] memory inputs) external view returns (StackItem[] memory) {
        return LibOpExponentialGrowth.referenceFn(opTestDefaultInterpreterState(), LibOperand.build(3, 1, 0), inputs);
    }

    function checkRunMatchesReference(Float base, Float rate, Float t) internal view {
        StackItem[] memory inputs = new StackItem[](3);
        inputs[0] = StackItem.wrap(Float.unwrap(base));
        inputs[1] = StackItem.wrap(Float.unwrap(rate));
        inputs[2] = StackItem.wrap(Float.unwrap(t));
        assertSameOutcome(abi.encodeCall(this.externalRun, (inputs)), abi.encodeCall(this.externalReference, (inputs)));
    }

    /// `run` and the in-library reference agree on every triple of floats,
    /// reverts included.
    function testOpExponentialGrowthRunMatchesReferenceAnyFloats(Float base, Float rate, Float t) external view {
        checkRunMatchesReference(base, rate, t);
    }

    /// `run` and the in-library reference agree where results are mostly in
    /// range.
    function testOpExponentialGrowthRunMatchesReferenceNearOne(
        int224 signedCoefficientBase,
        int32 exponentBase,
        int224 signedCoefficientRate,
        int32 exponentRate,
        int224 signedCoefficientT,
        int32 exponentT
    ) external view {
        exponentBase = int32(bound(exponentBase, -76, -56));
        exponentRate = int32(bound(exponentRate, -70, -66));
        exponentT = int32(bound(exponentT, -70, -64));
        checkRunMatchesReference(
            LibDecimalFloat.packLossless(signedCoefficientBase, exponentBase),
            LibDecimalFloat.packLossless(signedCoefficientRate, exponentRate),
            LibDecimalFloat.packLossless(signedCoefficientT, exponentT)
        );
    }
}
