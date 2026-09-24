// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {LibOpUnique} from "../../../../../src/lib/op/logic/LibOpUnique.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";

contract LibOpUniqueTest is OpTest {
    /// Directly test the integrity logic of LibOpUnique. This tests the happy
    /// path where the operand inputs and the calc inputs match.
    function testOpUniqueIntegrityHappy(IntegrityCheckState memory state, uint8 inputs, uint16 operandData)
        external
        pure
    {
        inputs = uint8(bound(inputs, 2, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpUnique.integrity(state, LibOperand.build(inputs, 1, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpUnique. Zero inputs is
    /// reported as the minimum of 2.
    function testOpUniqueIntegrityUnhappyZeroInputs(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpUnique.integrity(state, OperandV2.wrap(0));
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpUnique. One input is reported
    /// as the minimum of 2, because a lone value is vacuously unique.
    function testOpUniqueIntegrityUnhappyOneInput(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpUnique.integrity(state, OperandV2.wrap(bytes32(uint256(0x010000))));
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpUnique.
    function testOpUniqueRun(StackItem[] memory inputs, uint16 operandData) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.assume(inputs.length >= 2);
        vm.assume(inputs.length <= 0x0F);
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, operandData);
        opReferenceCheck(state, operand, LibOpUnique.referenceFn, LibOpUnique.integrity, LibOpUnique.run, inputs);
    }

    /// Directly test the runtime logic of LibOpUnique where a duplicate is
    /// guaranteed, so the reference check exercises the rejecting path rather
    /// than relying on the fuzzer to collide two values.
    function testOpUniqueRunWithDuplicate(StackItem[] memory inputs, uint256 duplicateIndex) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.assume(inputs.length >= 2);
        vm.assume(inputs.length <= 0x0F);
        duplicateIndex = bound(duplicateIndex, 1, inputs.length - 1);
        inputs[duplicateIndex] = inputs[0];
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(state, operand, LibOpUnique.referenceFn, LibOpUnique.integrity, LibOpUnique.run, inputs);
    }

    /// Zero inputs is a parse time error.
    function testOpUniqueEvalZeroInputs() external {
        checkBadInputs("_: unique();", 0, 2, 0);
    }

    /// One input is a parse time error.
    function testOpUniqueEvalOneInput() external {
        checkBadInputs("_: unique(1);", 1, 2, 1);
    }

    /// Zero outputs is a parse time error.
    function testOpUniqueEvalZeroOutputs() external {
        checkBadOutputs(": unique(1 2);", 2, 1, 0);
    }

    /// Two outputs is a parse time error.
    function testOpUniqueEvalTwoOutputs() external {
        checkBadOutputs("_ _: unique(1 2);", 2, 1, 2);
    }

    /// Two distinct values are unique.
    function testOpUniqueEval2InputsDistinct() external view {
        checkHappy("_: unique(1 2);", bytes32(uint256(1)), "1 2");
        checkHappy("_: unique(0 1);", bytes32(uint256(1)), "0 1");
        checkHappy("_: unique(-1 1);", bytes32(uint256(1)), "-1 1");
    }

    /// Two equal values are not unique.
    function testOpUniqueEval2InputsEqual() external view {
        checkHappy("_: unique(1 1);", 0, "1 1");
        checkHappy("_: unique(0 0);", 0, "0 0");
        checkHappy("_: unique(-1 -1);", 0, "-1 -1");
    }

    /// Equality is numerical, not binary, so different representations of the
    /// same number are not unique.
    function testOpUniqueEval2InputsNumericallyEqual() external view {
        checkHappy("_: unique(1 1e0);", 0, "1 1e0");
        checkHappy("_: unique(1e1 10);", 0, "1e1 10");
        checkHappy("_: unique(0.2 2e-1);", 0, "0.2 2e-1");
        checkHappy("_: unique(0 0e10);", 0, "0 0e10");
    }

    /// Three distinct values are unique.
    function testOpUniqueEval3InputsDistinct() external view {
        checkHappy("_: unique(1 2 3);", bytes32(uint256(1)), "1 2 3");
    }

    /// A duplicate anywhere in three values breaks uniqueness. The pairwise
    /// form this word replaces was easy to leave incomplete, so every pair is
    /// checked here.
    function testOpUniqueEval3InputsDuplicate() external view {
        checkHappy("_: unique(1 1 2);", 0, "1 1 2");
        checkHappy("_: unique(1 2 1);", 0, "1 2 1");
        checkHappy("_: unique(2 1 1);", 0, "2 1 1");
        checkHappy("_: unique(1 1 1);", 0, "1 1 1");
    }

    /// The maximum number of inputs, all distinct.
    function testOpUniqueEvalMaxInputsDistinct() external view {
        checkHappy("_: unique(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15);", bytes32(uint256(1)), "15 distinct");
    }

    /// The maximum number of inputs with the first and last colliding. This is
    /// the pair a naive implementation is most likely to miss.
    function testOpUniqueEvalMaxInputsFirstLastCollide() external view {
        checkHappy("_: unique(1 2 3 4 5 6 7 8 9 10 11 12 13 14 1);", 0, "15 with first == last");
    }

    /// Operands are disallowed.
    function testOpUniqueEvalOperandDisallowed() external {
        checkDisallowedOperand("_: unique<0>(1 2);");
        checkDisallowedOperand("_: unique<1>(1 2);");
        checkDisallowedOperand("_: unique<1 2>(1 2);");
    }
}
