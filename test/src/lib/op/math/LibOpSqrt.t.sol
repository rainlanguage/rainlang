// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, IntegrityCheckState, OperandV2, InterpreterState, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {PowNegativeBase} from "rain-math-float-0.3.10/src/error/ErrDecimalFloat.sol";
import {LibOpSqrt} from "../../../../../src/lib/op/math/LibOpSqrt.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibDecimalFloat, Float} from "rain-math-float-0.3.10/src/lib/LibDecimalFloat.sol";
import {StackItem} from "rainlang-interface-0.2.13/src/interface/IInterpreterV4.sol";

contract LibOpSqrtTest is OpTest {
    using LibDecimalFloat for Float;

    /// Directly test the integrity logic of LibOpSqrt.
    /// Inputs are always 1, outputs are always 1.
    function testOpSqrtIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpSqrt.integrity(state, operand);
        assertEq(calcInputs, 1);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpSqrt.
    function testOpSqrtRun(Float a) public view {
        vm.assume(!a.eq(LibDecimalFloat.FLOAT_MIN_NEGATIVE_VALUE));
        a = a.abs();
        InterpreterState memory state = opTestDefaultInterpreterState();

        OperandV2 operand = LibOperand.build(1, 1, 0);
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = StackItem.wrap(Float.unwrap(a));

        opReferenceCheck(state, operand, LibOpSqrt.referenceFn, LibOpSqrt.integrity, LibOpSqrt.run, inputs);
    }

    /// Test the eval of `sqrt`.
    function testOpSqrtEvalExamples() external view {
        checkHappy("_: sqrt(0);", 0, "0");
        checkHappy("_: sqrt(1);", Float.unwrap(LibDecimalFloat.packLossless(1e40, -40)), "1");
        checkHappy(
            "_: sqrt(0.5);",
            Float.unwrap(LibDecimalFloat.packLossless(70710678118654752440084436210484903928484, -41)),
            "0.5"
        );
        checkHappy(
            "_: sqrt(2);",
            Float.unwrap(LibDecimalFloat.packLossless(14142135623730950488016887242096980785697, -40)),
            "2"
        );
        checkHappy(
            "_: sqrt(2.5);",
            Float.unwrap(LibDecimalFloat.packLossless(15811388300841896659994467722163592668598, -40)),
            "2.5"
        );
    }

    /// Test the eval of `sqrt` for bad inputs.
    function testOpSqrtEvalBad() external {
        checkBadInputs("_: sqrt();", 0, 1, 0);
        checkBadInputs("_: sqrt(1 1);", 2, 1, 2);
    }

    function testOpSqrtEvalZeroOutputs() external {
        checkBadOutputs(": sqrt(1);", 1, 1, 0);
    }

    function testOpSqrtEvalTwoOutputs() external {
        checkBadOutputs("_ _: sqrt(1);", 1, 1, 2);
    }

    /// Test that sqrt of a negative number reverts.
    function testOpSqrtEvalNegativeInput() external {
        checkUnhappy("_: sqrt(-1);", abi.encodeWithSelector(PowNegativeBase.selector, -1, 0));
    }

    /// Test that operand is disallowed.
    function testOpSqrtEvalOperandDisallowed() external {
        checkUnhappyParse("_: sqrt<0>(1);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }

    function externalRun(StackItem[] memory inputs) external view returns (StackItem[] memory) {
        return opRunOutputs(LibOperand.build(1, 1, 0), LibOpSqrt.run, inputs);
    }

    function externalReference(StackItem[] memory inputs) external view returns (StackItem[] memory) {
        return LibOpSqrt.referenceFn(opTestDefaultInterpreterState(), LibOperand.build(1, 1, 0), inputs);
    }

    function checkRunMatchesReference(Float a) internal view {
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = StackItem.wrap(Float.unwrap(a));
        assertSameOutcome(abi.encodeCall(this.externalRun, (inputs)), abi.encodeCall(this.externalReference, (inputs)));
    }

    /// `run` and the in-library reference agree on every float, reverts
    /// included.
    function testOpSqrtRunMatchesReferenceAnyFloat(Float a) external view {
        checkRunMatchesReference(a);
    }

    /// `run` and the in-library reference agree where results are mostly in
    /// range.
    function testOpSqrtRunMatchesReferenceNearOne(int224 signedCoefficient, int32 exponent) external view {
        exponent = int32(bound(exponent, -76, -56));
        checkRunMatchesReference(LibDecimalFloat.packLossless(signedCoefficient, exponent));
    }
}
