// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {LibOpBinaryIn} from "../../../../../src/lib/op/logic/LibOpBinaryIn.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {BinaryInNeedlesZero} from "../../../../../src/error/ErrIntegrity.sol";
import {UnexpectedOperandValue} from "../../../../../src/error/ErrParse.sol";
import {OperandV2, StackItem} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";

contract LibOpBinaryInTest is OpTest {
    /// Directly test the integrity logic of LibOpBinaryIn. The happy path is any
    /// needle count from 1 up, with at least one more input than needles.
    function testOpBinaryInIntegrityHappy(IntegrityCheckState memory state, uint8 inputs, uint16 needles)
        external
        pure
    {
        inputs = uint8(bound(inputs, 2, 0x0F));
        needles = uint16(bound(needles, 1, inputs - 1));
        (uint256 calcInputs, uint256 calcOutputs) = LibOpBinaryIn.integrity(state, LibOperand.build(inputs, 1, needles));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpBinaryIn. When the bytecode
    /// declares no more inputs than there are needles the set would be empty,
    /// so the minimum of one more than the needle count is reported instead.
    function testOpBinaryInIntegrityUnhappyEmptySet(IntegrityCheckState memory state, uint8 inputs, uint16 needles)
        external
        pure
    {
        needles = uint16(bound(needles, 1, 0x0F));
        inputs = uint8(bound(inputs, 0, needles));
        (uint256 calcInputs, uint256 calcOutputs) = LibOpBinaryIn.integrity(state, LibOperand.build(inputs, 1, needles));

        assertEq(calcInputs, uint256(needles) + 1);
        assertEq(calcOutputs, 1);
    }

    /// Needle counts beyond the maximum input count can never be satisfied, so
    /// integrity reports a minimum that the bytecode cannot match.
    function testOpBinaryInIntegrityUnhappyNeedlesExceedInputs(IntegrityCheckState memory state, uint16 needles)
        external
        pure
    {
        needles = uint16(bound(needles, 0x10, type(uint16).max));
        (uint256 calcInputs, uint256 calcOutputs) = LibOpBinaryIn.integrity(state, LibOperand.build(0x0F, 1, needles));

        assertEq(calcInputs, uint256(needles) + 1);
        assertEq(calcOutputs, 1);
    }

    /// Zero needles would make the check vacuously true so it is rejected at
    /// integrity time.
    function testOpBinaryInIntegrityUnhappyZeroNeedles(IntegrityCheckState memory state, uint8 inputs) external {
        inputs = uint8(bound(inputs, 0, 0x0F));
        vm.expectRevert(abi.encodeWithSelector(BinaryInNeedlesZero.selector));
        this.externalIntegrity(state, LibOperand.build(inputs, 1, 0));
    }

    /// Wrapper so the integrity revert can be caught.
    function externalIntegrity(IntegrityCheckState memory state, OperandV2 operand)
        external
        pure
        returns (uint256, uint256)
    {
        return LibOpBinaryIn.integrity(state, operand);
    }

    /// Directly test the runtime logic of LibOpBinaryIn.
    function testOpBinaryInRun(StackItem[] memory inputs, uint16 needles) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.assume(inputs.length >= 2);
        vm.assume(inputs.length <= 0x0F);
        needles = uint16(bound(needles, 1, inputs.length - 1));
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, needles);
        opReferenceCheck(state, operand, LibOpBinaryIn.referenceFn, LibOpBinaryIn.integrity, LibOpBinaryIn.run, inputs);
    }

    /// Directly test the runtime logic of LibOpBinaryIn where every needle is
    /// guaranteed to be in the set, so the accepting path is exercised rather
    /// than relying on the fuzzer to collide values.
    function testOpBinaryInRunAllPresent(StackItem[] memory inputs, uint16 needles) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.assume(inputs.length >= 2);
        vm.assume(inputs.length <= 0x0F);
        needles = uint16(bound(needles, 1, inputs.length - 1));
        // Every needle is copied from the first member of the set.
        for (uint256 i = 0; i < needles; i++) {
            inputs[i] = inputs[needles];
        }
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, needles);
        opReferenceCheck(state, operand, LibOpBinaryIn.referenceFn, LibOpBinaryIn.integrity, LibOpBinaryIn.run, inputs);
    }

    /// An operand is required. Without it there is nothing marking where the
    /// needles end and the set begins.
    function testOpBinaryInEvalOperandDefaultsToOneNeedle() external view {
        // Omitting the operand means one needle, so this asks whether 1 is in
        // the set (2 1) rather than failing to parse.
        checkHappy("_: binary-in(1 2 1);", bytes32(uint256(1)), "default one needle, present");
        checkHappy("_: binary-in(1 2 3);", 0, "default one needle, absent");
        // Identical to writing the operand out.
        checkHappy("_: binary-in<1>(1 2 1);", bytes32(uint256(1)), "explicit one needle, present");
        checkHappy("_: binary-in<1>(1 2 3);", 0, "explicit one needle, absent");
    }

    /// An explicit zero is not a way of writing the default. It reaches the
    /// integrity check and reverts, because zero needles passes on nothing.
    function testOpBinaryInEvalExplicitZeroIsNotTheDefault() external {
        checkUnhappyParse2("_: binary-in<0>(1 2 1);", abi.encodeWithSelector(BinaryInNeedlesZero.selector));
    }

    /// A second operand value is not meaningful.
    function testOpBinaryInEvalTwoOperandValues() external {
        checkUnhappyParse("_: binary-in<1 1>(1 1);", abi.encodeWithSelector(UnexpectedOperandValue.selector));
    }

    /// Zero needles is rejected at deploy time.
    function testOpBinaryInEvalZeroNeedles() external {
        checkUnhappyParse2("_: binary-in<0>(1 1);", abi.encodeWithSelector(BinaryInNeedlesZero.selector));
    }

    /// The set must not be empty. The needles are the only inputs, so the
    /// opcode index counts the constants that precede it.
    function testOpBinaryInEvalEmptySet() external {
        checkBadInputs("_: binary-in<1>(1);", 1, 2, 1);
        checkBadInputs("_: binary-in<2>(1 2);", 2, 3, 2);
    }

    /// Zero outputs is a parse time error.
    function testOpBinaryInEvalZeroOutputs() external {
        checkBadOutputs(": binary-in<1>(1 1);", 2, 1, 0);
    }

    /// Two outputs is a parse time error.
    function testOpBinaryInEvalTwoOutputs() external {
        checkBadOutputs("_ _: binary-in<1>(1 1);", 2, 1, 2);
    }

    /// One needle against a one member set.
    function testOpBinaryInEval1Needle1Member() external view {
        checkHappy("_: binary-in<1>(1 1);", bytes32(uint256(1)), "1 in (1)");
        checkHappy("_: binary-in<1>(1 2);", 0, "1 in (2)");
    }

    /// One needle against a larger set. The needle is found at each position.
    function testOpBinaryInEval1NeedleManyMembers() external view {
        checkHappy("_: binary-in<1>(1 1 2 3);", bytes32(uint256(1)), "1 in (1 2 3)");
        checkHappy("_: binary-in<1>(2 1 2 3);", bytes32(uint256(1)), "2 in (1 2 3)");
        checkHappy("_: binary-in<1>(3 1 2 3);", bytes32(uint256(1)), "3 in (1 2 3)");
        checkHappy("_: binary-in<1>(4 1 2 3);", 0, "4 in (1 2 3)");
    }

    /// Multiple needles all have to be in the set.
    function testOpBinaryInEvalManyNeedles() external view {
        checkHappy("_: binary-in<2>(1 2 1 2 3);", bytes32(uint256(1)), "1 2 in (1 2 3)");
        checkHappy("_: binary-in<2>(1 4 1 2 3);", 0, "1 4 in (1 2 3)");
        checkHappy("_: binary-in<2>(4 1 1 2 3);", 0, "4 1 in (1 2 3)");
        checkHappy("_: binary-in<2>(4 5 1 2 3);", 0, "4 5 in (1 2 3)");
    }

    /// The same set member can satisfy more than one needle. The needles are
    /// not required to be distinct, that is what `unique` is for.
    function testOpBinaryInEvalRepeatedNeedles() external view {
        checkHappy("_: binary-in<2>(1 1 1 2);", bytes32(uint256(1)), "1 1 in (1 2)");
    }

    /// Membership is numerical equality, as per `equal-to`.
    function testOpBinaryInEvalNumericallyEqualIsNotMember() external view {
        // `0x01` and `10e-1` are the same number written as different words,
        // as `binary-equal-to`'s own tests pin. Membership is binary, so the
        // needle is NOT in a set holding only the other spelling.
        checkHappy("_: binary-in<1>(0x01 10e-1);", 0, "numerically equal, different word");
        // The same word matches.
        checkHappy("_: binary-in<1>(0x01 0x01);", bytes32(uint256(1)), "same word");
        // And is found among members it does not match.
        checkHappy("_: binary-in<1>(0x01 10e-1 0x01);", bytes32(uint256(1)), "same word present alongside another");
    }

    /// The maximum number of inputs, with the needle only in the last member.
    function testOpBinaryInEvalMaxInputs() external view {
        checkHappy("_: binary-in<1>(14 1 2 3 4 5 6 7 8 9 10 11 12 13 14);", bytes32(uint256(1)), "14 in last position");
        checkHappy("_: binary-in<1>(15 1 2 3 4 5 6 7 8 9 10 11 12 13 14);", 0, "15 not in set");
    }

    /// The allowlist check from the issue: two attestors that must both be
    /// allowlisted operators.
    function testOpBinaryInEvalAllowlist() external view {
        checkHappy("_: binary-in<2>(3 5 1 2 3 4 5 6);", bytes32(uint256(1)), "both allowlisted");
        checkHappy("_: binary-in<2>(3 7 1 2 3 4 5 6);", 0, "second not allowlisted");
    }
}
