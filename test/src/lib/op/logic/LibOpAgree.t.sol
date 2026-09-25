// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {LibOpAgree} from "../../../../../src/lib/op/logic/LibOpAgree.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {Float, LibDecimalFloat} from "rain-math-float-0.2.1/src/lib/LibDecimalFloat.sol";
import {AgreeToleranceNegative, AgreeTolerancesZero} from "../../../../../src/error/ErrEval.sol";

contract LibOpAgreeTest is OpTest {
    /// The fuzzed run tests below overwrite the two tolerance inputs with these
    /// rather than fuzzing them, because `validateTolerances` rejects negative
    /// and both-zero tolerances and random floats are negative about half the
    /// time. Fixing them costs the differential nothing: what it tests is the
    /// min/max walk over the VALUES, pointer arithmetic against array
    /// indexing, and the tolerances take no part in that. The arithmetic is
    /// pinned by the eval assertions, which the tolerances do vary across.
    function fuzzAbsoluteTolerance() internal pure returns (StackItem) {
        return StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));
    }

    function fuzzProportionalTolerance() internal pure returns (StackItem) {
        return StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, -2)));
    }

    /// Directly test the integrity logic of LibOpAgree. This tests the happy
    /// path where the operand inputs and the calc inputs match.
    function testOpAgreeIntegrityHappy(IntegrityCheckState memory state, uint8 inputs, uint16 operandData)
        external
        pure
    {
        inputs = uint8(bound(inputs, 4, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpAgree.integrity(state, LibOperand.build(inputs, 1, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpAgree. Fewer than two
    /// tolerances and two values is reported as the minimum of 4, because one
    /// value trivially agrees with itself.
    function testOpAgreeIntegrityUnhappyTooFewInputs(IntegrityCheckState memory state, uint8 inputs) external pure {
        inputs = uint8(bound(inputs, 0, 3));
        (uint256 calcInputs, uint256 calcOutputs) = LibOpAgree.integrity(state, LibOperand.build(inputs, 1, 0));

        assertEq(calcInputs, 4);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpAgree.
    function testOpAgreeRun(StackItem[] memory inputs, uint16 operandData) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.assume(inputs.length >= 4);
        vm.assume(inputs.length <= 0x0F);
        inputs[0] = fuzzAbsoluteTolerance();
        inputs[1] = fuzzProportionalTolerance();
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, operandData);
        opReferenceCheck(state, operand, LibOpAgree.referenceFn, LibOpAgree.integrity, LibOpAgree.run, inputs);
    }

    /// Directly test the runtime logic of LibOpAgree where every value is the
    /// same, so the zero spread path is exercised rather than relying on the
    /// fuzzer to land values near each other.
    function testOpAgreeRunAllValuesEqual(StackItem[] memory inputs) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.assume(inputs.length >= 4);
        vm.assume(inputs.length <= 0x0F);
        inputs[0] = fuzzAbsoluteTolerance();
        inputs[1] = fuzzProportionalTolerance();
        for (uint256 i = 3; i < inputs.length; i++) {
            inputs[i] = inputs[2];
        }
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(state, operand, LibOpAgree.referenceFn, LibOpAgree.integrity, LibOpAgree.run, inputs);
    }

    /// Zero inputs is a parse time error.
    function testOpAgreeEvalZeroInputs() external {
        checkBadInputs("_: agree();", 0, 4, 0);
    }

    /// A single tolerance is a parse time error. Both are always given.
    function testOpAgreeEvalOneInput() external {
        checkBadInputs("_: agree(0);", 1, 4, 1);
    }

    /// Two tolerances and no values is a parse time error.
    function testOpAgreeEvalTwoInputs() external {
        checkBadInputs("_: agree(0 0.01);", 2, 4, 2);
    }

    /// Two tolerances and a single value is a parse time error. One value
    /// trivially agrees with itself.
    function testOpAgreeEvalThreeInputs() external {
        checkBadInputs("_: agree(0 0.01 100);", 3, 4, 3);
    }

    /// Zero outputs is a parse time error.
    function testOpAgreeEvalZeroOutputs() external {
        checkBadOutputs(": agree(0 0.01 100 101);", 4, 1, 0);
    }

    /// Two outputs is a parse time error.
    function testOpAgreeEvalTwoOutputs() external {
        checkBadOutputs("_ _: agree(0 0.01 100 101);", 4, 1, 2);
    }

    /// Operands are disallowed. The input count is the only thing that varies.
    function testOpAgreeEvalOperandDisallowed() external {
        checkDisallowedOperand("_: agree<0>(0 0.01 100 101);");
        checkDisallowedOperand("_: agree<1>(0 0.01 100 101);");
        checkDisallowedOperand("_: agree<1 2>(0 0.01 100 101);");
    }

    /// The proportional tolerance is taken of the LARGEST MAGNITUDE among the
    /// values, so with positive values it is a proportion of the highest.
    ///
    /// 100 - 99 == 1 == 0.01 * 100, so this sits exactly on the limit and is
    /// accepted, because the check is `<=`. Anchoring on the lowest instead
    /// would give a limit of 0.01 * 99 == 0.99 and reject it, so these
    /// assertions distinguish the two anchors rather than merely exercising
    /// one.
    function testOpAgreeEvalProportionalBoundary() external view {
        checkHappy("_: agree(0 0.01 99 100);", bytes32(uint256(1)), "spread exactly a 1% proportional limit");
        checkHappy("_: agree(0 0.01 98.999999999999999999 100);", 0, "a hair over a 1% proportional limit");
        checkHappy(
            "_: agree(0 0.01 99.000000000000000001 100);", bytes32(uint256(1)), "a hair under a 1% proportional limit"
        );
    }

    /// The absolute tolerance is in the same units as the values and does not
    /// scale with them.
    function testOpAgreeEvalAbsoluteBoundary() external view {
        checkHappy("_: agree(1 0 100 101);", bytes32(uint256(1)), "spread exactly the absolute limit");
        checkHappy("_: agree(1 0 100 101.000000000000000001);", 0, "a hair over the absolute limit");
        checkHappy("_: agree(1 0 100 100.999999999999999999);", bytes32(uint256(1)), "a hair under the absolute limit");
    }

    /// THE LIMIT IS THE LARGER of the two terms, not their sum.
    ///
    /// Both cases below are constructed so that the sum and the max disagree,
    /// because a spread that falls between them is accepted by the sum and
    /// rejected by the max. Pinning both directions — proportional term
    /// dominant, then absolute term dominant — also rules out an
    /// implementation that always picks one side.
    function testOpAgreeEvalLimitIsTheLarger() external view {
        // Proportional dominant: max(0.5, 0.01 * 100) == 1, sum would be 1.5.
        checkHappy("_: agree(0.5 0.01 99 100);", bytes32(uint256(1)), "spread exactly the larger term");
        checkHappy("_: agree(0.5 0.01 98.999999999999999999 100);", 0, "a hair over the larger term");
        checkHappy("_: agree(0.5 0.01 98.8 100);", 0, "a spread the sum would have accepted");

        // Absolute dominant: max(5, 0.01 * 100) == 5, sum would be 6.
        checkHappy("_: agree(5 0.01 95 100);", bytes32(uint256(1)), "spread exactly the larger term, absolute side");
        checkHappy("_: agree(5 0.01 94.999999999999999999 100);", 0, "a hair over the larger term, absolute side");
        checkHappy("_: agree(5 0.01 94.5 100);", 0, "a spread the sum would have accepted, absolute side");
    }

    /// Identical values agree within any valid tolerance.
    function testOpAgreeEvalZeroSpread() external view {
        checkHappy("_: agree(0 0.01 100 100);", bytes32(uint256(1)), "proportional tolerance, zero spread");
        checkHappy("_: agree(1 0 100 100);", bytes32(uint256(1)), "absolute tolerance, zero spread");
    }

    /// BOTH tolerances zero would be an exact equality check, which is
    /// `equal-to`'s job, so it reverts rather than quietly becoming one. This
    /// holds whatever the values are — it is a property of the tolerances
    /// alone, so it reverts even where the answer would have been 1.
    function testOpAgreeEvalBothTolerancesZeroReverts() external {
        checkUnhappy("_: agree(0 0 100 101);", abi.encodeWithSelector(AgreeTolerancesZero.selector));
        checkUnhappy("_: agree(0 0 100 100);", abi.encodeWithSelector(AgreeTolerancesZero.selector));
        // Every representation of zero is caught, because the sign and
        // zero-ness of a float live entirely in its coefficient.
        checkUnhappy("_: agree(0e0 0.0 100 100);", abi.encodeWithSelector(AgreeTolerancesZero.selector));
    }

    /// Either tolerance ALONE may be zero. That is how an expression asks for
    /// only the other one, and it is what both of the spec's example calls do.
    function testOpAgreeEvalOneToleranceZeroIsFine() external view {
        checkHappy("_: agree(0 0.01 99 100);", bytes32(uint256(1)), "zero absolute, proportional carries it");
        checkHappy("_: agree(1 0 100 101);", bytes32(uint256(1)), "zero proportional, absolute carries it");
    }

    /// A NEGATIVE tolerance reverts. The spread is a distance and so never
    /// negative, which makes a negative tolerance meaningless rather than
    /// merely strict.
    ///
    /// The case that motivates reverting rather than defining it is
    /// `agree(1 -0.01 100 100.5)`. Because the limit is the LARGER of the two
    /// terms, a negative tolerance is simply dominated by the other one, so
    /// without this check that call answers 1 — a guard silently succeeding on
    /// malformed input, which is the one outcome a guard must not have.
    function testOpAgreeEvalNegativeToleranceReverts() external {
        checkUnhappy("_: agree(-1 0.01 99 100);", abi.encodeWithSelector(AgreeToleranceNegative.selector));
        checkUnhappy("_: agree(0 -0.01 100 100);", abi.encodeWithSelector(AgreeToleranceNegative.selector));
        checkUnhappy("_: agree(1 -0.01 100 100.5);", abi.encodeWithSelector(AgreeToleranceNegative.selector));
        checkUnhappy("_: agree(-1 -0.01 100 100);", abi.encodeWithSelector(AgreeToleranceNegative.selector));
        // Reverts on the tolerances alone, even where the values are identical
        // and every valid tolerance would have answered 1.
        checkUnhappy("_: agree(-1 0 100 100);", abi.encodeWithSelector(AgreeToleranceNegative.selector));
    }

    /// Only the highest and the lowest value matter, so the order the values
    /// are passed in does not.
    function testOpAgreeEvalOrderIrrelevant() external view {
        checkHappy("_: agree(0 0.01 100 99);", bytes32(uint256(1)), "highest last");
        checkHappy("_: agree(0 0.01 99 99.5 100);", bytes32(uint256(1)), "ascending");
        checkHappy("_: agree(0 0.01 100 99.5 99);", bytes32(uint256(1)), "descending");
        checkHappy("_: agree(0 0.01 99.5 100 99);", bytes32(uint256(1)), "middle first");
    }

    /// The spread is the largest pairwise difference, so bounding it bounds
    /// every pair and one outlier rejects the whole set.
    function testOpAgreeEvalOutlier() external view {
        checkHappy("_: agree(0 0.01 100 100.5 102);", 0, "high outlier");
        checkHappy("_: agree(0 0.01 100 100.5 98);", 0, "low outlier");
    }

    /// The proportional tolerance scales with the values, so the same spread
    /// passes at a large magnitude and fails at a small one. The absolute
    /// tolerance does the opposite, which is why both are taken.
    function testOpAgreeEvalScaling() external view {
        checkHappy("_: agree(0 0.01 1000 1001);", bytes32(uint256(1)), "1 apart at 1000, proportional");
        checkHappy("_: agree(0 0.01 10 11);", 0, "1 apart at 10, proportional");
        checkHappy("_: agree(1 0 1000 1001);", bytes32(uint256(1)), "1 apart at 1000, absolute");
        checkHappy("_: agree(1 0 10 11);", bytes32(uint256(1)), "1 apart at 10, absolute");
    }

    /// The anchor is a MAGNITUDE, so negative values behave the way positive
    /// ones do. Anchoring on the signed highest instead would give a negative
    /// limit here and reject values one part in a hundred apart.
    ///
    /// -99 - -100 == 1 == 0.01 * abs(-100), which is the same boundary as the
    /// positive case reflected through zero.
    function testOpAgreeEvalNegativeValues() external view {
        checkHappy("_: agree(0 0.01 -100 -99);", bytes32(uint256(1)), "spread exactly 1% of the largest magnitude");
        checkHappy("_: agree(0 0.01 -100 -98.999999999999999999);", 0, "a hair over 1% on negatives");
        checkHappy("_: agree(0 0.01 -100 -100);", bytes32(uint256(1)), "identical negatives");
    }

    /// The anchor is the largest magnitude across the whole list, which for
    /// values straddling zero is whichever end is further from it.
    ///
    /// Anchoring on the lowest would take abs(-1) == 1 here and give a limit of
    /// 1, rejecting the first case.
    function testOpAgreeEvalStraddlingZero() external view {
        // Spread is 101, limit is 0 + (1.01 * 100) == 101.
        checkHappy("_: agree(0 1.01 -1 100);", bytes32(uint256(1)), "anchored on the positive end");
        checkHappy("_: agree(0 1 -1 100);", 0, "a limit of 100 against a spread of 101");
        // Reflected: the negative end is now the larger magnitude.
        checkHappy("_: agree(0 1.01 -100 1);", bytes32(uint256(1)), "anchored on the negative end");
        checkHappy("_: agree(0 1 -100 1);", 0, "a limit of 100 against a spread of 101, reflected");
    }

    /// WHY BOTH TOLERANCES EXIST. A proportional tolerance alone collapses as
    /// the values approach zero: the anchor shrinks with them, so values that
    /// agree by any practical measure read as far apart. The absolute
    /// tolerance is what covers that part of the domain.
    function testOpAgreeEvalNearZero() external view {
        // Anchor 0.001, limit 0.00001, spread 0.002.
        checkHappy("_: agree(0 0.01 -0.001 0.001);", 0, "a 1% proportional tolerance collapses near zero");
        // The same values against an absolute tolerance of 0.01.
        checkHappy("_: agree(0.01 0 -0.001 0.001);", bytes32(uint256(1)), "an absolute tolerance covers near zero");
    }

    /// A zero anchor collapses the proportional term to zero whatever the
    /// tolerance, so only the absolute term can accept a spread there.
    function testOpAgreeEvalZeroValues() external view {
        checkHappy("_: agree(0 0.01 0 0);", bytes32(uint256(1)), "all zero, zero spread");
        checkHappy("_: agree(0 1000 0 0);", bytes32(uint256(1)), "all zero, huge proportional tolerance");
        // Anchor is 1, not 0, because it is the largest magnitude rather than
        // the lowest value.
        checkHappy("_: agree(0 1 0 1);", bytes32(uint256(1)), "zero lowest, anchored on the highest");
        checkHappy("_: agree(0 0.99 0 1);", 0, "zero lowest, limit just under the spread");
    }

    /// The most negative representable value is a valid value. Taking its
    /// magnitude with `Float.abs` reverts with `ExponentOverflow`, because the
    /// magnitude does not fit the packed coefficient at the maximum exponent.
    /// The magnitude is taken on the unpacked coefficient instead, so the word
    /// answers rather than reverting.
    function testOpAgreeEvalMinNegativeValue() external view {
        checkHappy(
            "_: agree(0 0.01 min-negative-value() min-negative-value());",
            bytes32(uint256(1)),
            "identical most negative values"
        );
        checkHappy("_: agree(0 0.01 min-negative-value() 0);", 0, "most negative value against zero");
    }

    /// The other end of the range is not a special case, but it is the other
    /// half of the boundary.
    function testOpAgreeEvalMaxPositiveValue() external view {
        checkHappy(
            "_: agree(0 0.01 max-positive-value() max-positive-value());",
            bytes32(uint256(1)),
            "identical most positive values"
        );
        checkHappy("_: agree(0 0.01 min-negative-value() max-positive-value());", 0, "opposite extremes");
    }

    /// The comparison is numerical, not binary, so the representation of the
    /// tolerances and the values does not matter.
    function testOpAgreeEvalNumericalEquality() external view {
        checkHappy("_: agree(0 1e-2 99 100);", bytes32(uint256(1)), "proportional tolerance as 1e-2");
        checkHappy("_: agree(0e0 0.01 99 100);", bytes32(uint256(1)), "absolute tolerance as 0e0");
        checkHappy("_: agree(0 0.01 9.9e1 1e2);", bytes32(uint256(1)), "values in exponent form");
        checkHappy("_: agree(0.0 0.010 99.0 100.00);", bytes32(uint256(1)), "trailing zeros");
    }

    /// The maximum number of inputs is two tolerances and thirteen values.
    ///
    /// Anchored on 100.9 the limit is 1.009, so a lowest of 100 agrees and a
    /// lowest of 99 does not.
    function testOpAgreeEvalMaxInputs() external view {
        checkHappy(
            "_: agree(0 0.01 100 100.1 100.2 100.3 100.4 100.5 100.6 100.7 100.8 100.9 100.05 100.25 100.5);",
            bytes32(uint256(1)),
            "13 values within 1% of the largest"
        );
        checkHappy(
            "_: agree(0 0.01 100 100.1 100.2 100.3 100.4 100.5 100.6 100.7 100.8 100.9 100.05 100.25 99);",
            0,
            "13 values with one outlier"
        );
    }

    /// The price agreement check from the issue. Three independently attested
    /// prices agree within a maximum deviation, with an explicit zero absolute
    /// tolerance asserting the prices stay away from zero.
    function testOpAgreeEvalAttestedPrices() external view {
        checkHappy("_: agree(0 0.001 1000 1000.5 1000.9);", bytes32(uint256(1)), "prices agree within 0.1%");
        checkHappy("_: agree(0 0.001 1000 1000.5 1001.5);", 0, "prices disagree beyond 0.1%");
    }

    /// The time agreement check from the issue. A time is an offset from an
    /// epoch, so a proportion of it means nothing and the proportional
    /// tolerance is an explicit zero.
    function testOpAgreeEvalAttestedTimes() external view {
        checkHappy("_: agree(60 0 1700000000 1700000030 1700000059);", bytes32(uint256(1)), "times within 60 seconds");
        checkHappy(
            "_: agree(60 0 1700000000 1700000030 1700000060);", bytes32(uint256(1)), "times exactly 60 seconds apart"
        );
        checkHappy("_: agree(60 0 1700000000 1700000030 1700000061);", 0, "times more than 60 seconds apart");
    }
}
