// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, IntegrityCheckState, OperandV2, InterpreterState, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpExp2} from "../../../../../src/lib/op/math/LibOpExp2.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibDecimalFloat, Float} from "rain-math-float-0.3.10/src/lib/LibDecimalFloat.sol";
import {StackItem} from "rainlang-interface-0.2.13/src/interface/IInterpreterV4.sol";

contract LibOpExp2Test is OpTest {
    /// Directly test the integrity logic of LibOpExp2.
    /// Inputs are always 1, outputs are always 1.
    function testOpExp2Integrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpExp2.integrity(state, operand);
        assertEq(calcInputs, 1);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpExp2.
    function testOpExp2Run(int224 signedCoefficientA, int32 exponentA, uint16 operandData) public view {
        signedCoefficientA = int224(bound(signedCoefficientA, 0, 10000));
        exponentA = int32(bound(exponentA, -10, 5));
        InterpreterState memory state = opTestDefaultInterpreterState();
        Float a = LibDecimalFloat.packLossless(signedCoefficientA, exponentA);

        OperandV2 operand = LibOperand.build(1, 1, operandData);
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = StackItem.wrap(Float.unwrap(a));

        opReferenceCheck(state, operand, LibOpExp2.referenceFn, LibOpExp2.integrity, LibOpExp2.run, inputs);
    }

    /// Test the eval of `exp2`.
    function testOpExp2EvalExample() external view {
        checkHappy("_: exp2(0);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "2^0");
        checkHappy("_: exp2(1);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "2^1");
        checkHappy(
            "_: exp2(0.5);",
            Float.unwrap(LibDecimalFloat.packLossless(14142135623730950488016887242096980785697, -40)),
            "2^0.5"
        );
        checkHappy("_: exp2(2);", Float.unwrap(LibDecimalFloat.packLossless(4, 0)), "2^2");
        checkHappy("_: exp2(3);", Float.unwrap(LibDecimalFloat.packLossless(8, 0)), "2^3");
    }

    /// Test exp2 with negative input. exp2(-1) = 0.5.
    function testOpExp2EvalNegativeInput() external view {
        (Float expected,) = LibDecimalFloat.packLossy(50000000000000000000000000000000000000000, -41);
        checkHappy("_: exp2(-1);", Float.unwrap(expected), "2^(-1)");
    }

    /// Test the eval of `exp2` for bad inputs.
    function testOpExp2EvalBad() external {
        checkBadInputs("_: exp2();", 0, 1, 0);
        checkBadInputs("_: exp2(1 1);", 2, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpExp2EvalOperandDisallowed() external {
        checkUnhappyParse("_: exp2<0>(1);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }

    function testOpExp2ZeroOutputs() external {
        checkBadOutputs(": exp2(1);", 1, 1, 0);
    }

    function testOpExp2TwoOutputs() external {
        checkBadOutputs("_ _: exp2(1);", 1, 1, 2);
    }

    function externalRun(StackItem[] memory inputs) external view returns (StackItem[] memory) {
        return opRunOutputs(LibOperand.build(1, 1, 0), LibOpExp2.run, inputs);
    }

    function externalReference(StackItem[] memory inputs) external view returns (StackItem[] memory) {
        return LibOpExp2.referenceFn(opTestDefaultInterpreterState(), LibOperand.build(1, 1, 0), inputs);
    }

    function checkRunMatchesReference(Float a) internal view {
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = StackItem.wrap(Float.unwrap(a));
        assertSameOutcome(abi.encodeCall(this.externalRun, (inputs)), abi.encodeCall(this.externalReference, (inputs)));
    }

    /// `run` and the in-library reference agree on every float, reverts
    /// included.
    function testOpExp2RunMatchesReferenceAnyFloat(Float a) external view {
        checkRunMatchesReference(a);
    }

    /// `run` and the in-library reference agree where results are mostly in
    /// range.
    function testOpExp2RunMatchesReferenceNearOne(int224 signedCoefficient, int32 exponent) external view {
        exponent = int32(bound(exponent, -70, -64));
        checkRunMatchesReference(LibDecimalFloat.packLossless(signedCoefficient, exponent));
    }
}
