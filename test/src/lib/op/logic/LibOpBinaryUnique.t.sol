// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {LibOpBinaryUnique} from "../../../../../src/lib/op/logic/LibOpBinaryUnique.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";

contract LibOpBinaryUniqueTest is OpTest {
    /// Directly test the integrity logic of LibOpBinaryUnique. This tests the happy
    /// path where the operand inputs and the calc inputs match.
    function testOpBinaryUniqueIntegrityHappy(IntegrityCheckState memory state, uint8 inputs, uint16 operandData)
        external
        pure
    {
        inputs = uint8(bound(inputs, 2, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpBinaryUnique.integrity(state, LibOperand.build(inputs, 1, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpBinaryUnique. Zero inputs is
    /// reported as the minimum of 2.
    function testOpBinaryUniqueIntegrityUnhappyZeroInputs(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpBinaryUnique.integrity(state, OperandV2.wrap(0));
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpBinaryUnique. One input is reported
    /// as the minimum of 2, because a lone value is vacuously unique.
    function testOpBinaryUniqueIntegrityUnhappyOneInput(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpBinaryUnique.integrity(state, OperandV2.wrap(bytes32(uint256(0x010000))));
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpBinaryUnique.
    function testOpBinaryUniqueRun(StackItem[] memory inputs, uint16 operandData) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.assume(inputs.length >= 2);
        vm.assume(inputs.length <= 0x0F);
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, operandData);
        opReferenceCheck(
            state, operand, LibOpBinaryUnique.referenceFn, LibOpBinaryUnique.integrity, LibOpBinaryUnique.run, inputs
        );
    }

    /// Directly test the runtime logic of LibOpBinaryUnique where a duplicate is
    /// guaranteed, so the reference check exercises the rejecting path rather
    /// than relying on the fuzzer to collide two values.
    function testOpBinaryUniqueRunWithDuplicate(StackItem[] memory inputs, uint256 duplicateIndex) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.assume(inputs.length >= 2);
        vm.assume(inputs.length <= 0x0F);
        duplicateIndex = bound(duplicateIndex, 1, inputs.length - 1);
        inputs[duplicateIndex] = inputs[0];
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(
            state, operand, LibOpBinaryUnique.referenceFn, LibOpBinaryUnique.integrity, LibOpBinaryUnique.run, inputs
        );
    }

    /// Zero inputs is a parse time error.
    function testOpBinaryUniqueEvalZeroInputs() external {
        checkBadInputs("_: binary-unique();", 0, 2, 0);
    }

    /// One input is a parse time error.
    function testOpBinaryUniqueEvalOneInput() external {
        checkBadInputs("_: binary-unique(1);", 1, 2, 1);
    }

    /// Zero outputs is a parse time error.
    function testOpBinaryUniqueEvalZeroOutputs() external {
        checkBadOutputs(": binary-unique(1 2);", 2, 1, 0);
    }

    /// Two outputs is a parse time error.
    function testOpBinaryUniqueEvalTwoOutputs() external {
        checkBadOutputs("_ _: binary-unique(1 2);", 2, 1, 2);
    }

    /// Two distinct values are unique.
    function testOpBinaryUniqueEval2InputsDistinct() external view {
        checkHappy("_: binary-unique(1 2);", bytes32(uint256(1)), "1 2");
        checkHappy("_: binary-unique(0 1);", bytes32(uint256(1)), "0 1");
        checkHappy("_: binary-unique(-1 1);", bytes32(uint256(1)), "-1 1");
    }

    /// Two equal values are not unique.
    function testOpBinaryUniqueEval2InputsEqual() external view {
        checkHappy("_: binary-unique(1 1);", 0, "1 1");
        checkHappy("_: binary-unique(0 0);", 0, "0 0");
        checkHappy("_: binary-unique(-1 -1);", 0, "-1 -1");
    }

    /// Equality is numerical, not binary, so different representations of the
    /// same number are not unique.
    function testOpBinaryUniqueEval2InputsNumericallyEqualAreDistinct() external view {
        // Distinctness is binary, so two words that are the same number
        // written differently ARE distinct here — the opposite of what a
        // numerical uniqueness check would answer.
        checkHappy("_: binary-unique(0x01 10e-1);", bytes32(uint256(1)), "numerically equal, different words");
        // Identical words are not distinct.
        checkHappy("_: binary-unique(0x01 0x01);", 0, "same word twice");
        checkHappy("_: binary-unique(0x01 10e-1 0x01);", 0, "same word repeated among distinct ones");
    }

    /// Three distinct values are unique.
    function testOpBinaryUniqueEval3InputsDistinct() external view {
        checkHappy("_: binary-unique(1 2 3);", bytes32(uint256(1)), "1 2 3");
    }

    /// A duplicate anywhere in three values breaks uniqueness. The pairwise
    /// form this word replaces was easy to leave incomplete, so every pair is
    /// checked here.
    function testOpBinaryUniqueEval3InputsDuplicate() external view {
        checkHappy("_: binary-unique(1 1 2);", 0, "1 1 2");
        checkHappy("_: binary-unique(1 2 1);", 0, "1 2 1");
        checkHappy("_: binary-unique(2 1 1);", 0, "2 1 1");
        checkHappy("_: binary-unique(1 1 1);", 0, "1 1 1");
    }

    /// The maximum number of inputs, all distinct.
    function testOpBinaryUniqueEvalMaxInputsDistinct() external view {
        checkHappy("_: binary-unique(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15);", bytes32(uint256(1)), "15 distinct");
    }

    /// The maximum number of inputs with the first and last colliding. This is
    /// the pair a naive implementation is most likely to miss.
    function testOpBinaryUniqueEvalMaxInputsFirstLastCollide() external view {
        checkHappy("_: binary-unique(1 2 3 4 5 6 7 8 9 10 11 12 13 14 1);", 0, "15 with first == last");
    }

    /// Operands are disallowed.
    function testOpBinaryUniqueEvalOperandDisallowed() external {
        checkDisallowedOperand("_: binary-unique<0>(1 2);");
        checkDisallowedOperand("_: binary-unique<1>(1 2);");
        checkDisallowedOperand("_: binary-unique<1 2>(1 2);");
    }
}
