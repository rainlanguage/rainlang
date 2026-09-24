// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {LibOpAgreeAbsolute} from "../../../../../src/lib/op/logic/LibOpAgreeAbsolute.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";

contract LibOpAgreeAbsoluteTest is OpTest {
    /// Directly test the integrity logic of LibOpAgreeAbsolute. This tests the
    /// happy path where the operand inputs and the calc inputs match.
    function testOpAgreeAbsoluteIntegrityHappy(IntegrityCheckState memory state, uint8 inputs, uint16 operandData)
        external
        pure
    {
        inputs = uint8(bound(inputs, 3, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpAgreeAbsolute.integrity(state, LibOperand.build(inputs, 1, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpAgreeAbsolute. Fewer than a
    /// tolerance and two values is reported as the minimum of 3, because one
    /// value trivially agrees with itself.
    function testOpAgreeAbsoluteIntegrityUnhappyTooFewInputs(IntegrityCheckState memory state, uint8 inputs)
        external
        pure
    {
        inputs = uint8(bound(inputs, 0, 2));
        (uint256 calcInputs, uint256 calcOutputs) = LibOpAgreeAbsolute.integrity(state, LibOperand.build(inputs, 1, 0));

        assertEq(calcInputs, 3);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpAgreeAbsolute.
    function testOpAgreeAbsoluteRun(StackItem[] memory inputs, uint16 operandData) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.assume(inputs.length >= 3);
        vm.assume(inputs.length <= 0x0F);
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, operandData);
        opReferenceCheck(
            state, operand, LibOpAgreeAbsolute.referenceFn, LibOpAgreeAbsolute.integrity, LibOpAgreeAbsolute.run, inputs
        );
    }

    /// Directly test the runtime logic of LibOpAgreeAbsolute where every value
    /// is the same, so the zero spread path is exercised rather than relying
    /// on the fuzzer to land values near each other.
    function testOpAgreeAbsoluteRunAllValuesEqual(StackItem[] memory inputs) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.assume(inputs.length >= 3);
        vm.assume(inputs.length <= 0x0F);
        for (uint256 i = 2; i < inputs.length; i++) {
            inputs[i] = inputs[1];
        }
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(
            state, operand, LibOpAgreeAbsolute.referenceFn, LibOpAgreeAbsolute.integrity, LibOpAgreeAbsolute.run, inputs
        );
    }

    /// Zero inputs is a parse time error.
    function testOpAgreeAbsoluteEvalZeroInputs() external {
        checkBadInputs("_: agree-absolute();", 0, 3, 0);
    }

    /// A tolerance with no values is a parse time error.
    function testOpAgreeAbsoluteEvalOneInput() external {
        checkBadInputs("_: agree-absolute(1);", 1, 3, 1);
    }

    /// A tolerance and a single value is a parse time error. One value
    /// trivially agrees with itself.
    function testOpAgreeAbsoluteEvalTwoInputs() external {
        checkBadInputs("_: agree-absolute(1 100);", 2, 3, 2);
    }

    /// Zero outputs is a parse time error.
    function testOpAgreeAbsoluteEvalZeroOutputs() external {
        checkBadOutputs(": agree-absolute(1 100 101);", 3, 1, 0);
    }

    /// Two outputs is a parse time error.
    function testOpAgreeAbsoluteEvalTwoOutputs() external {
        checkBadOutputs("_ _: agree-absolute(1 100 101);", 3, 1, 2);
    }

    /// Operands are disallowed. The input count is the only thing that varies.
    function testOpAgreeAbsoluteEvalOperandDisallowed() external {
        checkDisallowedOperand("_: agree-absolute<0>(1 100 101);");
        checkDisallowedOperand("_: agree-absolute<1>(1 100 101);");
        checkDisallowedOperand("_: agree-absolute<1 2>(1 100 101);");
    }

    /// A spread of exactly the tolerance is accepted, because the check is
    /// `<=`.
    function testOpAgreeAbsoluteEvalBoundary() external view {
        checkHappy("_: agree-absolute(1 100 101);", bytes32(uint256(1)), "spread exactly the tolerance");
        checkHappy("_: agree-absolute(1 100 101.000000000000000001);", 0, "a hair over the tolerance");
        checkHappy(
            "_: agree-absolute(1 100 100.999999999999999999);", bytes32(uint256(1)), "a hair under the tolerance"
        );
    }

    /// Identical values agree within any non negative tolerance, including
    /// zero.
    function testOpAgreeAbsoluteEvalZeroSpread() external view {
        checkHappy("_: agree-absolute(0 100 100);", bytes32(uint256(1)), "zero tolerance, zero spread");
        checkHappy("_: agree-absolute(1 100 100);", bytes32(uint256(1)), "nonzero tolerance, zero spread");
    }

    /// A zero tolerance rejects any spread at all.
    function testOpAgreeAbsoluteEvalZeroTolerance() external view {
        checkHappy("_: agree-absolute(0 100 101);", 0, "zero tolerance, nonzero spread");
        checkHappy("_: agree-absolute(0 100 100.000000000000000001);", 0, "zero tolerance, tiny spread");
    }

    /// The spread is never negative, so a negative tolerance rejects
    /// everything.
    function testOpAgreeAbsoluteEvalNegativeTolerance() external view {
        checkHappy("_: agree-absolute(-1 100 100);", 0, "negative tolerance, zero spread");
        checkHappy("_: agree-absolute(-1 100 101);", 0, "negative tolerance, nonzero spread");
    }

    /// Only the highest and the lowest value matter, so the order the values
    /// are passed in does not.
    function testOpAgreeAbsoluteEvalOrderIrrelevant() external view {
        checkHappy("_: agree-absolute(1 101 100);", bytes32(uint256(1)), "highest first");
        checkHappy("_: agree-absolute(1 100 100.5 101);", bytes32(uint256(1)), "ascending");
        checkHappy("_: agree-absolute(1 101 100.5 100);", bytes32(uint256(1)), "descending");
        checkHappy("_: agree-absolute(1 100.5 101 100);", bytes32(uint256(1)), "middle first");
    }

    /// Every value has to be within the tolerance of every other, so one
    /// outlier rejects the whole set.
    function testOpAgreeAbsoluteEvalOutlier() external view {
        checkHappy("_: agree-absolute(1 100 100.5 102);", 0, "high outlier");
        checkHappy("_: agree-absolute(1 100 100.5 98);", 0, "low outlier");
    }

    /// The tolerance is absolute, not proportional, so the same spread passes
    /// or fails independently of the magnitude of the values. This is the
    /// difference between this word and `agree`.
    function testOpAgreeAbsoluteEvalMagnitudeIrrelevant() external view {
        checkHappy("_: agree-absolute(1 1000000 1000001);", bytes32(uint256(1)), "1 apart at 1000000");
        checkHappy("_: agree-absolute(1 0.5 1.5);", bytes32(uint256(1)), "1 apart at 0.5");
        checkHappy("_: agree-absolute(1 1000000 1000002);", 0, "2 apart at 1000000");
        checkHappy("_: agree-absolute(1 0.5 2.5);", 0, "2 apart at 0.5");
    }

    /// Negative values are compared by their spread the same as positive ones.
    function testOpAgreeAbsoluteEvalNegativeValues() external view {
        checkHappy("_: agree-absolute(1 -100 -99);", bytes32(uint256(1)), "1 apart on negatives");
        checkHappy("_: agree-absolute(1 -100 -98);", 0, "2 apart on negatives");
        checkHappy("_: agree-absolute(1 -100 -100);", bytes32(uint256(1)), "identical negatives");
    }

    /// Values that straddle zero are just another spread, with no special
    /// case.
    function testOpAgreeAbsoluteEvalStraddlingZero() external view {
        checkHappy("_: agree-absolute(2 -1 1);", bytes32(uint256(1)), "spread of 2 within a tolerance of 2");
        checkHappy("_: agree-absolute(1 -1 1);", 0, "spread of 2 outside a tolerance of 1");
        checkHappy("_: agree-absolute(1 -0.5 0.5);", bytes32(uint256(1)), "spread of 1 straddling zero");
    }

    /// A lowest value of zero has no bearing on an absolute tolerance, unlike
    /// `agree` where it collapses the limit to zero.
    function testOpAgreeAbsoluteEvalZeroLowest() external view {
        checkHappy("_: agree-absolute(1 0 0);", bytes32(uint256(1)), "all zero");
        checkHappy("_: agree-absolute(1 0 1);", bytes32(uint256(1)), "zero lowest within tolerance");
        checkHappy("_: agree-absolute(1 0 2);", 0, "zero lowest outside tolerance");
    }

    /// The extremes of the representable range are ordinary values here. There
    /// is no magnitude of the lowest value to take, unlike `agree`.
    function testOpAgreeAbsoluteEvalExtremes() external view {
        checkHappy(
            "_: agree-absolute(1 min-negative-value() min-negative-value());",
            bytes32(uint256(1)),
            "identical most negative values"
        );
        checkHappy(
            "_: agree-absolute(1 max-positive-value() max-positive-value());",
            bytes32(uint256(1)),
            "identical most positive values"
        );
        checkHappy("_: agree-absolute(1 min-negative-value() max-positive-value());", 0, "opposite extremes");
    }

    /// The comparison is numerical, not binary, so the representation of the
    /// tolerance and the values does not matter.
    function testOpAgreeAbsoluteEvalNumericalEquality() external view {
        checkHappy("_: agree-absolute(1e0 100 101);", bytes32(uint256(1)), "tolerance as 1e0");
        checkHappy("_: agree-absolute(1 1e2 1.01e2);", bytes32(uint256(1)), "values in exponent form");
        checkHappy("_: agree-absolute(1.0 100.0 101.00);", bytes32(uint256(1)), "trailing zeros");
    }

    /// The maximum number of inputs is a tolerance and fourteen values.
    function testOpAgreeAbsoluteEvalMaxInputs() external view {
        checkHappy(
            "_: agree-absolute(1 100 100.1 100.2 100.3 100.4 100.5 100.6 100.7 100.8 100.9 101 100.5 100.2 100);",
            bytes32(uint256(1)),
            "14 values within 1"
        );
        checkHappy(
            "_: agree-absolute(1 100 100.1 100.2 100.3 100.4 100.5 100.6 100.7 100.8 100.9 101 100.5 100.2 99);",
            0,
            "14 values with one outlier"
        );
    }

    /// The timestamp agreement check from the issue. Signed timestamps have to
    /// agree with each other and with the chain clock, which is a single call
    /// with the chain clock passed in as one of the values.
    function testOpAgreeAbsoluteEvalAttestedTimes() external view {
        checkHappy(
            "_: agree-absolute(60 1700000000 1700000030 1700000059);", bytes32(uint256(1)), "times within 60 seconds"
        );
        checkHappy(
            "_: agree-absolute(60 1700000000 1700000030 1700000060);",
            bytes32(uint256(1)),
            "times exactly 60 seconds apart"
        );
        checkHappy("_: agree-absolute(60 1700000000 1700000030 1700000061);", 0, "times more than 60 seconds apart");
    }
}
