// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {LibOpAgree} from "../../../../../src/lib/op/logic/LibOpAgree.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";

contract LibOpAgreeTest is OpTest {
    /// Directly test the integrity logic of LibOpAgree. This tests the happy
    /// path where the operand inputs and the calc inputs match.
    function testOpAgreeIntegrityHappy(IntegrityCheckState memory state, uint8 inputs, uint16 operandData)
        external
        pure
    {
        inputs = uint8(bound(inputs, 3, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpAgree.integrity(state, LibOperand.build(inputs, 1, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpAgree. Fewer than a tolerance
    /// and two values is reported as the minimum of 3, because one value
    /// trivially agrees with itself.
    function testOpAgreeIntegrityUnhappyTooFewInputs(IntegrityCheckState memory state, uint8 inputs) external pure {
        inputs = uint8(bound(inputs, 0, 2));
        (uint256 calcInputs, uint256 calcOutputs) = LibOpAgree.integrity(state, LibOperand.build(inputs, 1, 0));

        assertEq(calcInputs, 3);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpAgree.
    function testOpAgreeRun(StackItem[] memory inputs, uint16 operandData) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.assume(inputs.length >= 3);
        vm.assume(inputs.length <= 0x0F);
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, operandData);
        opReferenceCheck(state, operand, LibOpAgree.referenceFn, LibOpAgree.integrity, LibOpAgree.run, inputs);
    }

    /// Directly test the runtime logic of LibOpAgree where every value is the
    /// same, so the zero spread path is exercised rather than relying on the
    /// fuzzer to land values near each other.
    function testOpAgreeRunAllValuesEqual(StackItem[] memory inputs) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.assume(inputs.length >= 3);
        vm.assume(inputs.length <= 0x0F);
        for (uint256 i = 2; i < inputs.length; i++) {
            inputs[i] = inputs[1];
        }
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(state, operand, LibOpAgree.referenceFn, LibOpAgree.integrity, LibOpAgree.run, inputs);
    }

    /// Zero inputs is a parse time error.
    function testOpAgreeEvalZeroInputs() external {
        checkBadInputs("_: agree();", 0, 3, 0);
    }

    /// A tolerance with no values is a parse time error.
    function testOpAgreeEvalOneInput() external {
        checkBadInputs("_: agree(0.01);", 1, 3, 1);
    }

    /// A tolerance and a single value is a parse time error. One value
    /// trivially agrees with itself.
    function testOpAgreeEvalTwoInputs() external {
        checkBadInputs("_: agree(0.01 100);", 2, 3, 2);
    }

    /// Zero outputs is a parse time error.
    function testOpAgreeEvalZeroOutputs() external {
        checkBadOutputs(": agree(0.01 100 101);", 3, 1, 0);
    }

    /// Two outputs is a parse time error.
    function testOpAgreeEvalTwoOutputs() external {
        checkBadOutputs("_ _: agree(0.01 100 101);", 3, 1, 2);
    }

    /// Operands are disallowed. The input count is the only thing that varies.
    function testOpAgreeEvalOperandDisallowed() external {
        checkDisallowedOperand("_: agree<0>(0.01 100 101);");
        checkDisallowedOperand("_: agree<1>(0.01 100 101);");
        checkDisallowedOperand("_: agree<1 2>(0.01 100 101);");
    }

    /// The tolerance is a proportion of the lowest value. A spread of exactly
    /// the tolerance is accepted, because the check is `<=`.
    function testOpAgreeEvalBoundary() external view {
        // 101 - 100 == 1 == 0.01 * 100.
        checkHappy("_: agree(0.01 100 101);", bytes32(uint256(1)), "1% spread against a 1% tolerance");
        // One unit in the last place over the limit is rejected.
        checkHappy("_: agree(0.01 100 101.000000000000000001);", 0, "a hair over a 1% tolerance");
        // One unit in the last place under the limit is accepted.
        checkHappy("_: agree(0.01 100 100.999999999999999999);", bytes32(uint256(1)), "a hair under a 1% tolerance");
    }

    /// Identical values agree within any non negative tolerance, including
    /// zero.
    function testOpAgreeEvalZeroSpread() external view {
        checkHappy("_: agree(0 100 100);", bytes32(uint256(1)), "zero tolerance, zero spread");
        checkHappy("_: agree(0.01 100 100);", bytes32(uint256(1)), "1% tolerance, zero spread");
    }

    /// A zero tolerance rejects any spread at all.
    function testOpAgreeEvalZeroTolerance() external view {
        checkHappy("_: agree(0 100 101);", 0, "zero tolerance, nonzero spread");
        checkHappy("_: agree(0 100 100.000000000000000001);", 0, "zero tolerance, tiny spread");
    }

    /// The spread is never negative, so a negative tolerance rejects
    /// everything.
    function testOpAgreeEvalNegativeTolerance() external view {
        checkHappy("_: agree(-0.01 100 100);", 0, "negative tolerance, zero spread");
        checkHappy("_: agree(-0.01 100 101);", 0, "negative tolerance, nonzero spread");
    }

    /// Only the highest and the lowest value matter, so the order the values
    /// are passed in does not.
    function testOpAgreeEvalOrderIrrelevant() external view {
        checkHappy("_: agree(0.01 101 100);", bytes32(uint256(1)), "highest first");
        checkHappy("_: agree(0.01 100 100.5 101);", bytes32(uint256(1)), "ascending");
        checkHappy("_: agree(0.01 101 100.5 100);", bytes32(uint256(1)), "descending");
        checkHappy("_: agree(0.01 100.5 101 100);", bytes32(uint256(1)), "middle first");
    }

    /// Every value has to be within the tolerance of every other, so one
    /// outlier rejects the whole set.
    function testOpAgreeEvalOutlier() external view {
        checkHappy("_: agree(0.01 100 100.5 102);", 0, "high outlier");
        checkHappy("_: agree(0.01 100 100.5 98);", 0, "low outlier");
    }

    /// The tolerance is proportional, so the same spread passes at a large
    /// magnitude and fails at a small one.
    function testOpAgreeEvalProportional() external view {
        checkHappy("_: agree(0.01 1000 1001);", bytes32(uint256(1)), "1 apart at 1000");
        checkHappy("_: agree(0.01 10 11);", 0, "1 apart at 10");
        checkHappy("_: agree(0.01 100 101);", bytes32(uint256(1)), "1 apart at 100");
    }

    /// The proportion is taken of the magnitude of the lowest value, so
    /// negative values behave the same way positive ones do rather than
    /// rejecting values identical to each other.
    function testOpAgreeEvalNegativeValues() external view {
        // -99 - -100 == 1 == 0.01 * abs(-100).
        checkHappy("_: agree(0.01 -100 -99);", bytes32(uint256(1)), "1% spread on negatives");
        checkHappy("_: agree(0.01 -100 -98.9);", 0, "1.1% spread on negatives");
        checkHappy("_: agree(0.01 -100 -100);", bytes32(uint256(1)), "identical negatives");
    }

    /// Values that straddle zero are measured against the magnitude of the
    /// lowest, which is the most negative value rather than the one closest to
    /// zero.
    function testOpAgreeEvalStraddlingZero() external view {
        // Spread is 2, limit is 0.01 * abs(-1) == 0.01.
        checkHappy("_: agree(0.01 -1 1);", 0, "1% tolerance straddling zero");
        // Spread is 2, limit is 3 * abs(-1) == 3.
        checkHappy("_: agree(3 -1 1);", bytes32(uint256(1)), "300% tolerance straddling zero");
        // Spread is 2, limit is 2 * abs(-1) == 2, so the boundary is accepted.
        checkHappy("_: agree(2 -1 1);", bytes32(uint256(1)), "200% tolerance straddling zero");
    }

    /// A lowest value of zero gives a limit of zero whatever the tolerance is,
    /// so only an exactly zero spread agrees.
    function testOpAgreeEvalZeroLowest() external view {
        checkHappy("_: agree(0.01 0 0);", bytes32(uint256(1)), "all zero");
        checkHappy("_: agree(0.01 0 1);", 0, "zero lowest, nonzero spread");
        checkHappy("_: agree(1000 0 0.000000000000000001);", 0, "zero lowest, huge tolerance");
    }

    /// The most negative representable value is a valid lowest value. Taking
    /// its magnitude with `Float.abs` reverts with `ExponentOverflow`, because
    /// the magnitude does not fit the packed coefficient at the maximum
    /// exponent. The magnitude is taken on the unpacked coefficient instead,
    /// so the word answers rather than reverting.
    function testOpAgreeEvalMinNegativeValue() external view {
        checkHappy(
            "_: agree(0.01 min-negative-value() min-negative-value());",
            bytes32(uint256(1)),
            "identical most negative values"
        );
        checkHappy("_: agree(0.01 min-negative-value() 0);", 0, "most negative value against zero");
    }

    /// The other end of the range is not a special case, but it is the other
    /// half of the boundary.
    function testOpAgreeEvalMaxPositiveValue() external view {
        checkHappy(
            "_: agree(0.01 max-positive-value() max-positive-value());",
            bytes32(uint256(1)),
            "identical most positive values"
        );
        checkHappy("_: agree(0.01 min-negative-value() max-positive-value());", 0, "opposite extremes");
    }

    /// The comparison is numerical, not binary, so the representation of the
    /// tolerance and the values does not matter.
    function testOpAgreeEvalNumericalEquality() external view {
        checkHappy("_: agree(1e-2 100 101);", bytes32(uint256(1)), "tolerance as 1e-2");
        checkHappy("_: agree(0.01 1e2 1.01e2);", bytes32(uint256(1)), "values in exponent form");
        checkHappy("_: agree(0.010 100.0 101.00);", bytes32(uint256(1)), "trailing zeros");
    }

    /// The maximum number of inputs is a tolerance and fourteen values.
    function testOpAgreeEvalMaxInputs() external view {
        checkHappy(
            "_: agree(0.01 100 100.1 100.2 100.3 100.4 100.5 100.6 100.7 100.8 100.9 101 100.5 100.2 100);",
            bytes32(uint256(1)),
            "14 values within 1%"
        );
        checkHappy(
            "_: agree(0.01 100 100.1 100.2 100.3 100.4 100.5 100.6 100.7 100.8 100.9 101 100.5 100.2 99);",
            0,
            "14 values with one outlier"
        );
    }

    /// The price agreement check from the issue. Three independently attested
    /// prices have to agree within a maximum deviation.
    function testOpAgreeEvalAttestedPrices() external view {
        checkHappy("_: agree(0.001 1000 1000.5 1000.9);", bytes32(uint256(1)), "prices agree within 0.1%");
        checkHappy("_: agree(0.001 1000 1000.5 1001.5);", 0, "prices disagree beyond 0.1%");
    }
}
