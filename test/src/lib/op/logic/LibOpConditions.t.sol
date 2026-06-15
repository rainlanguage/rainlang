// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {LibUint256Array} from "rain-solmem-0.1.3/src/lib/LibUint256Array.sol";

import {LibPointer, Pointer} from "rain-solmem-0.1.3/src/lib/LibPointer.sol";

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpConditions} from "../../../../../src/lib/op/logic/LibOpConditions.sol";
import {IntegrityCheckState, BadOpInputsLength} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {OperandV2, StackItem} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterV4.sol";
import {LibIntOrAString, IntOrAString} from "rain-intorastring-0.1.0/src/lib/LibIntOrAString.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {Float, LibDecimalFloat} from "rain-math-float-0.1.1/src/lib/LibDecimalFloat.sol";

contract LibOpConditionsTest is OpTest {
    using LibUint256Array for uint256[];
    using LibDecimalFloat for Float;
    using LibPointer for Pointer;

    /// Directly test the integrity logic of LibOpConditions. This tests the happy
    /// path where the operand is valid.
    function testOpConditionsIntegrityHappy(
        IntegrityCheckState memory state,
        uint8 inputs,
        uint8 outputs,
        uint16 operandData
    ) external pure {
        inputs = uint8(bound(inputs, 0, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpConditions.integrity(state, LibOperand.build(inputs, outputs, operandData));

        uint256 expectedCalcInputs = inputs;
        // Calc inputs will be minimum 2.
        if (inputs < 2) {
            expectedCalcInputs = 2;
        }
        assertEq(calcInputs, expectedCalcInputs, "calc inputs");
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpConditions.
    function testOpConditionsRun(StackItem[] memory inputs, Float finalNonZero) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();

        // Ensure that we have inputs that are a valid pairwise conditions.
        vm.assume(inputs.length > 1);
        vm.assume(inputs.length <= 0x0F);
        if (inputs.length % 2 != 0) {
            uint256[] memory inputsIntArray;
            assembly ("memory-safe") {
                inputsIntArray := inputs
            }
            inputsIntArray.truncate(inputs.length - 1);
        }
        // Ensure the final condition is nonzero so that we don't error.
        if (Float.wrap(StackItem.unwrap(inputs[inputs.length - 2])).isZero()) {
            vm.assume(!finalNonZero.isZero());
            inputs[inputs.length - 2] = StackItem.wrap(Float.unwrap(finalNonZero));
        }
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(
            state, operand, LibOpConditions.referenceFn, LibOpConditions.integrity, LibOpConditions.run, inputs
        );
    }

    function _testOpConditionsRunNoConditionsMet(StackItem[] memory inputs, OperandV2 operand) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();

        opReferenceCheck(
            state, operand, LibOpConditions.referenceFn, LibOpConditions.integrity, LibOpConditions.run, inputs
        );
    }

    /// External wrapper that invokes ONLY `LibOpConditions.run`. Unlike
    /// `opReferenceCheck`, no reference implementation is called, so a revert
    /// here can only originate from `run` itself. This isolates the
    /// "no condition met" revert from the reference implementation's own revert.
    /// Returns both the value left at the resulting stack top and the number of
    /// words the stack top advanced (i.e. inputs consumed below the output), so
    /// callers can assert exactly where `run` placed its single output.
    function runExternal(OperandV2 operand, StackItem[] memory inputs)
        external
        view
        returns (StackItem value, uint256 stackTopWordsConsumed)
    {
        InterpreterState memory state = opTestDefaultInterpreterState();
        // The inputs array's data region is a contiguous run of words, which is
        // exactly the stack layout `run` expects. The first input is at the top
        // of the stack.
        Pointer stackTop;
        assembly ("memory-safe") {
            stackTop := add(inputs, 0x20)
        }
        Pointer stackTopAfter = LibOpConditions.run(state, operand, stackTop);
        stackTopWordsConsumed = (Pointer.unwrap(stackTopAfter) - Pointer.unwrap(stackTop)) / 0x20;
        value = StackItem.wrap(stackTopAfter.unsafeReadWord());
    }

    /// Test the error case where no conditions are met.
    function testOpConditionsRunNoConditionsMet(StackItem[] memory inputs, string memory reason) external {
        vm.assume(bytes(reason).length <= 31);
        // Ensure that we have inputs that are a valid pairwise conditions.
        vm.assume(inputs.length > 1);
        if (inputs.length > 0x0F) {
            uint256[] memory inputsIntArray;
            assembly ("memory-safe") {
                inputsIntArray := inputs
            }
            inputsIntArray.truncate(0x0F);
        }

        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);

        // Ensure all the conditions are zero so that we error.
        for (uint256 i = 0; i < inputs.length; i += 2) {
            inputs[i] = StackItem.wrap(0);
        }

        if (inputs.length % 2 != 0) {
            inputs[inputs.length - 1] =
                StackItem.wrap(bytes32(IntOrAString.unwrap(LibIntOrAString.fromStringV3(reason))));
        } else {
            reason = "";
        }

        vm.expectRevert(bytes(reason));
        this._testOpConditionsRunNoConditionsMet(inputs, operand);
    }

    /// Test the eval of conditions opcode parsed from a string. Tests 1 true input 1 zero output.
    function testOpConditionsEval1TrueInputZeroOutput() external view {
        checkHappy("_: conditions(5 0);", Float.unwrap(LibDecimalFloat.packLossless(0, 0)), "");
    }

    /// Test the eval of conditions opcode parsed from a string. Tests 1 nonzero
    /// input 1 nonzero output.
    function testOpConditionsEval2MixedInputs() external view {
        checkHappy("_: conditions(5 6);", Float.unwrap(LibDecimalFloat.packLossless(6, 0)), "");
    }

    /// Test that if conditions are NOT met, the expression reverts.
    function testOpConditionsEval1FalseInputRevert() external {
        checkUnhappy("_: conditions(0 5);", "");
    }

    /// Test that conditions can take an error code as an operand.
    function testOpConditionsEvalErrorCode() external {
        checkUnhappy("_: conditions(0x00 0x00 0x00 0x00 \"fail\");", "fail");
    }

    /// Directly test that `run` itself reverts when no condition is met, with an
    /// even number of inputs (no reason input), so the revert reason is empty.
    /// This calls `run` in isolation (via `runExternal`) so the revert can only
    /// come from `run`, not from a reference implementation.
    function testOpConditionsRunRevertsNoMatchEven() external {
        StackItem[] memory inputs = new StackItem[](2);
        // Condition is zero so no condition is met.
        inputs[0] = StackItem.wrap(0);
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(6, 0)));
        OperandV2 operand = LibOperand.build(2, 1, 0);
        vm.expectRevert(bytes(""));
        this.runExternal(operand, inputs);
    }

    /// Directly test that `run` itself reverts when no condition is met, with an
    /// odd number of inputs, so the revert reason is the trailing reason input.
    /// This calls `run` in isolation (via `runExternal`) so the revert can only
    /// come from `run`, not from a reference implementation.
    function testOpConditionsRunRevertsNoMatchOddReason() external {
        StackItem[] memory inputs = new StackItem[](3);
        // Both conditions zero so no condition is met.
        inputs[0] = StackItem.wrap(0);
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(6, 0)));
        // The trailing reason input.
        inputs[2] = StackItem.wrap(bytes32(IntOrAString.unwrap(LibIntOrAString.fromStringV3("boom"))));
        OperandV2 operand = LibOperand.build(3, 1, 0);
        vm.expectRevert(bytes("boom"));
        this.runExternal(operand, inputs);
    }

    /// Test the eval of conditions opcode parsed from a string. Tests 1 zero
    /// then 1 nonzero condition.
    function testOpConditionsEval1FalseInput1TrueInput() external view {
        checkHappy("_: conditions(0 9 3 4);", Float.unwrap(LibDecimalFloat.packLossless(4, 0)), "");
    }

    /// Test the eval of conditions opcode parsed from a string. Tests 2 true
    /// conditions. The first should be used.
    function testOpConditionsEval2TrueInputs() external view {
        checkHappy("_: conditions(5 6 7 8);", Float.unwrap(LibDecimalFloat.packLossless(6, 0)), "");
    }

    /// Test the eval of conditions opcode parsed from a string. Tests 1 nonzero
    /// condition then 1 zero condition.
    function testOpConditionsEval1TrueInput1FalseInput() external view {
        checkHappy("_: conditions(5 6 0 9);", Float.unwrap(LibDecimalFloat.packLossless(6, 0)), "");
    }

    /// Test the eval of conditions opcode parsed from a string with an ODD number
    /// of inputs (the trailing input is the error reason) where the first
    /// condition is met. The matched value must be returned and the trailing
    /// reason input must be ignored. This exercises the odd-input success path
    /// where the result is written into the slot occupied by the reason input.
    function testOpConditionsEval3InputsTrueOddReason() external view {
        checkHappy("_: conditions(1 6 \"ignored\");", Float.unwrap(LibDecimalFloat.packLossless(6, 0)), "");
    }

    /// Test the eval of conditions opcode parsed from a string with an ODD number
    /// of inputs (the trailing input is the error reason) where the first pair is
    /// false and the second pair is true. The second value must be returned and
    /// the trailing reason input must be ignored.
    function testOpConditionsEval5InputsSecondTrueOddReason() external view {
        checkHappy("_: conditions(0 9 1 7 \"ignored\");", Float.unwrap(LibDecimalFloat.packLossless(7, 0)), "");
    }

    /// Directly test where `run` places its output for an ODD number of inputs
    /// when a condition is met. With 3 inputs (one condition/value pair plus a
    /// trailing reason input) the output must be written into the slot above the
    /// pair (the slot occupied by the reason input), so the stack top advances by
    /// 2 words (the condition and value are consumed) and the output value is the
    /// matched value. This asserts the resulting stack top pointer, not just the
    /// value, so a mutation that placed the output one slot lower is caught.
    function testOpConditionsRunOddMatchStackTopPlacement() external view {
        StackItem[] memory inputs = new StackItem[](3);
        // First condition is nonzero (met) with value 6.
        inputs[0] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(6, 0)));
        // Trailing reason input, which must be ignored on the success path.
        inputs[2] = StackItem.wrap(bytes32(IntOrAString.unwrap(LibIntOrAString.fromStringV3("ignored"))));
        OperandV2 operand = LibOperand.build(3, 1, 0);
        (StackItem value, uint256 stackTopWordsConsumed) = this.runExternal(operand, inputs);
        // The condition and value words are consumed below the single output.
        assertEq(stackTopWordsConsumed, 2, "stack top placement");
        assertEq(StackItem.unwrap(value), Float.unwrap(LibDecimalFloat.packLossless(6, 0)), "matched value");
    }

    /// Test that conditions without inputs fails integrity check.
    function testOpConditionsEvalFail0Inputs() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 0, 2, 0));
        bytes memory bytecode = I_DEPLOYER.parse2("_: conditions();");
        (bytecode);
    }

    /// Test that conditions with 1 inputs fails integrity check.
    function testOpConditionsEvalFail1Inputs() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 1, 2, 1));
        bytes memory bytecode = I_DEPLOYER.parse2("_: conditions(0x00);");
        (bytecode);
    }

    /// Test the eval of `conditions` parsed from a string. Tests the unhappy path
    /// where an operand is provided.
    function testOpConditionsEvalUnhappyOperand() external {
        checkUnhappyParse("_ :conditions<0>(1 1 \"foo\");", abi.encodeWithSelector(UnexpectedOperand.selector));
    }

    function testOpConditionsZeroOutputs() external {
        checkBadOutputs(": conditions(0x00 0x00);", 2, 1, 0);
    }

    function testOpConditionsTwoOutputs() external {
        checkBadOutputs("_ _: conditions(0x00 0x00);", 2, 1, 2);
    }
}
