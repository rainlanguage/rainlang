// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, IntegrityCheckState, OperandV2, InterpreterState, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpGm} from "../../../../../src/lib/op/math/LibOpGm.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibDecimalFloat, Float} from "rain-math-float-0.3.11/src/lib/LibDecimalFloat.sol";
import {StackItem} from "../../../../../src/interface/IInterpreterV4.sol";

contract LibOpGmTest is OpTest {
    /// Directly test the integrity logic of LibOpGm.
    /// Inputs are always 2, outputs are always 1.
    function testOpGmIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpGm.integrity(state, operand);
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpGm. Fuzz inputs include negative
    /// values to exercise the signed geometric mean logic.
    function testOpGmRun(
        int224 signedCoefficientA,
        int32 exponentA,
        int224 signedCoefficientB,
        int32 exponentB,
        uint16 operandData
    ) public view {
        signedCoefficientA = int224(bound(signedCoefficientA, -10000, 10000));
        exponentA = int32(bound(exponentA, -10, 5));
        signedCoefficientB = int224(bound(signedCoefficientB, -10000, 10000));
        exponentB = int32(bound(exponentB, -10, 5));

        InterpreterState memory state = opTestDefaultInterpreterState();

        Float a = LibDecimalFloat.packLossless(signedCoefficientA, exponentA);
        Float b = LibDecimalFloat.packLossless(signedCoefficientB, exponentB);

        OperandV2 operand = LibOperand.build(2, 1, operandData);
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(Float.unwrap(a));
        inputs[1] = StackItem.wrap(Float.unwrap(b));

        opReferenceCheck(state, operand, LibOpGm.referenceFn, LibOpGm.integrity, LibOpGm.run, inputs);
    }

    /// Test the eval of `gm` with non-negative inputs.
    function testOpGmEval() external view {
        checkHappy("_: gm(0 0);", 0, "0 0");
        checkHappy("_: gm(0 1);", 0, "0 1");
        checkHappy("_: gm(1 0);", 0, "1 0");
        checkHappy("_: gm(1 1);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "1 1");
        checkHappy(
            "_: gm(1 2);",
            Float.unwrap(LibDecimalFloat.packLossless(14142135623730950488016887242096980785697, -40)),
            "1 2"
        );
        checkHappy("_: gm(2 2);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "2 2");
        checkHappy(
            "_: gm(2 3);",
            Float.unwrap(LibDecimalFloat.packLossless(24494897427831780981972840747058913919659, -40)),
            "2 3"
        );
        checkHappy(
            "_: gm(2 4);",
            Float.unwrap(LibDecimalFloat.packLossless(28284271247461900976033774484193961571393, -40)),
            "2 4"
        );
        checkHappy(
            "_: gm(4 0.5);",
            Float.unwrap(LibDecimalFloat.packLossless(14142135623730950488016887242096980785697, -40)),
            "4 0.5"
        );
    }

    /// Products past every Float return their mean rather than reverting.
    function testOpGmEvalProductPastEveryFloat() external view {
        checkHappy(
            "_: gm(max-positive-value() max-positive-value());",
            Float.unwrap(LibDecimalFloat.FLOAT_MAX_POSITIVE_VALUE),
            "max max"
        );
        checkHappy(
            "_: gm(1e2000000000 1e2000000000);",
            Float.unwrap(LibDecimalFloat.packLossless(1, 2000000000)),
            "1e2000000000 1e2000000000"
        );
        checkHappy(
            "_: gm(-1e2000000000 1e2000000000);",
            Float.unwrap(LibDecimalFloat.packLossless(-1, 2000000000)),
            "-1e2000000000 1e2000000000"
        );
    }

    /// Test that gm with mixed signs returns a negative result.
    /// gm(-1, 1) = -sqrt(|-1| * |1|) = -1.
    function testOpGmEvalMixedSignsNegativeFirst() external view {
        (Float expected,) = LibDecimalFloat.packLossy(-1, 0);
        checkHappy("_: gm(-1 1);", Float.unwrap(expected), "-1 1");
    }

    /// Test that gm with mixed signs returns a negative result regardless of
    /// argument order. gm(1, -1) = -sqrt(|1| * |-1|) = -1.
    function testOpGmEvalMixedSignsNegativeSecond() external view {
        (Float expected,) = LibDecimalFloat.packLossy(-1, 0);
        checkHappy("_: gm(1 -1);", Float.unwrap(expected), "1 -1");
    }

    /// Test that gm with mixed signs and non-unit magnitudes returns a negative
    /// result. gm(-2, 3) = -sqrt(|-2| * |3|) = -sqrt(6) ≈ -2.4494897427831780981972840747058913919659.
    function testOpGmEvalMixedSignsNonUnit() external view {
        (Float expected,) = LibDecimalFloat.packLossy(-24494897427831780981972840747058913919659, -40);
        checkHappy("_: gm(-2 3);", Float.unwrap(expected), "-2 3");
    }

    /// Test that gm with both inputs negative returns a positive result.
    /// gm(-1, -1) = sqrt(|-1| * |-1|) = 1.
    function testOpGmEvalBothNegativeEqual() external view {
        checkHappy("_: gm(-1 -1);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "-1 -1");
    }

    /// Test that gm with both inputs negative and unequal returns a positive
    /// result. gm(-2, -3) = sqrt(|-2| * |-3|) = sqrt(6) ≈ 2.4494897427831780981972840747058913919659.
    function testOpGmEvalBothNegativeUnequal() external view {
        checkHappy(
            "_: gm(-2 -3);",
            Float.unwrap(LibDecimalFloat.packLossless(24494897427831780981972840747058913919659, -40)),
            "-2 -3"
        );
    }

    /// Test that gm with zero and a negative input returns zero.
    function testOpGmEvalZeroWithNegative() external view {
        checkHappy("_: gm(0 -1);", 0, "0 -1");
    }

    /// Test that gm with a negative input and zero returns zero.
    function testOpGmEvalNegativeWithZero() external view {
        checkHappy("_: gm(-1 0);", 0, "-1 0");
    }

    /// Test that gm produces identical bytes for zero regardless of whether
    /// the sign logic triggers minus(0). gm(0, -1) has aNeg!=bNeg so it
    /// negates the zero result; this must produce the same bytes as gm(0, 1).
    function testOpGmEvalZeroBytesIdentical() external view {
        checkHappy("_: gm(0 -1);", Float.unwrap(LibDecimalFloat.FLOAT_ZERO), "0 -1 vs FLOAT_ZERO");
        checkHappy("_: gm(-1 0);", Float.unwrap(LibDecimalFloat.FLOAT_ZERO), "-1 0 vs FLOAT_ZERO");
    }

    /// Test the eval of `gm` for bad inputs.
    function testOpGmOneInput() external {
        checkBadInputs("_: gm(1);", 1, 2, 1);
    }

    function testOpGmThreeInputs() external {
        checkBadInputs("_: gm(1 1 1);", 3, 2, 3);
    }

    function testOpGmZeroOutputs() external {
        checkBadOutputs(": gm(1 1);", 2, 1, 0);
    }

    function testOpGmTwoOutputs() external {
        checkBadOutputs("_ _: gm(1 1);", 2, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpGmEvalOperandDisallowed() external {
        checkUnhappyParse("_: gm<0>(1 1);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }

    function externalRun(StackItem[] memory inputs) external view returns (StackItem[] memory) {
        return opRunOutputs(LibOperand.build(2, 1, 0), LibOpGm.run, inputs);
    }

    function externalReference(StackItem[] memory inputs) external view returns (StackItem[] memory) {
        return LibOpGm.referenceFn(opTestDefaultInterpreterState(), LibOperand.build(2, 1, 0), inputs);
    }

    function checkRunMatchesReference(Float a, Float b) internal view {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(Float.unwrap(a));
        inputs[1] = StackItem.wrap(Float.unwrap(b));
        assertSameOutcome(abi.encodeCall(this.externalRun, (inputs)), abi.encodeCall(this.externalReference, (inputs)));
    }

    /// `run` and the in-library reference agree on every pair of floats,
    /// reverts included.
    function testOpGmRunMatchesReferenceAnyFloats(Float a, Float b) external view {
        checkRunMatchesReference(a, b);
    }

    /// `run` and the in-library reference agree where results are mostly in
    /// range.
    function testOpGmRunMatchesReferenceNearOne(
        int224 signedCoefficientA,
        int32 exponentA,
        int224 signedCoefficientB,
        int32 exponentB
    ) external view {
        exponentA = int32(bound(exponentA, -76, -56));
        exponentB = int32(bound(exponentB, -76, -56));
        checkRunMatchesReference(
            LibDecimalFloat.packLossless(signedCoefficientA, exponentA),
            LibDecimalFloat.packLossless(signedCoefficientB, exponentB)
        );
    }
}
