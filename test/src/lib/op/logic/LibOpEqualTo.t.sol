// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpEqualTo} from "../../../../../src/lib/op/logic/LibOpEqualTo.sol";
import {IntegrityCheckState, BadOpInputsLength} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {OpcodeIOOverflow} from "../../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../../src/lib/parse/LibParseError.sol";

contract LibOpEqualToTest is OpTest {
    /// Directly test the integrity logic of LibOpEqualTo. The calc inputs must
    /// match the operand inputs, and the calc outputs must be 1.
    function testOpEqualToIntegrityHappy(
        IntegrityCheckState memory state,
        uint8 inputs,
        uint8 outputs,
        uint16 operandData
    ) external pure {
        inputs = uint8(bound(inputs, 2, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpEqualTo.integrity(state, LibOperand.build(inputs, outputs, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpEqualTo. This tests the
    /// unhappy path where the operand is invalid due to 0 inputs.
    function testOpEqualToIntegrityUnhappyZeroInputs(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpEqualTo.integrity(state, OperandV2.wrap(0));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpEqualTo. This tests the
    /// unhappy path where the operand is invalid due to 1 input.
    function testOpEqualToIntegrityUnhappyOneInput(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpEqualTo.integrity(state, OperandV2.wrap(bytes32(uint256(0x010000))));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpEqualTo.
    function testOpEqualToRun(StackItem input1, StackItem input2) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = input1;
        inputs[1] = input2;
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(state, operand, LibOpEqualTo.referenceFn, LibOpEqualTo.integrity, LibOpEqualTo.run, inputs);
    }

    /// Directly test the runtime logic of LibOpEqualTo for an arbitrary number
    /// of inputs.
    function testOpEqualToRunVariadic(StackItem[] memory inputs) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.assume(inputs.length >= 2);
        vm.assume(inputs.length <= 0x0F);
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(state, operand, LibOpEqualTo.referenceFn, LibOpEqualTo.integrity, LibOpEqualTo.run, inputs);
    }

    /// Directly test the runtime logic of LibOpEqualTo for an arbitrary number
    /// of inputs that are all equal to each other. Random inputs are unlikely
    /// to ever be equal, so this covers the all-equal branch of the loop.
    function testOpEqualToRunVariadicAllEqual(StackItem input, uint8 length) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        length = uint8(bound(length, 2, 0x0F));
        StackItem[] memory inputs = new StackItem[](length);
        for (uint256 i = 0; i < inputs.length; i++) {
            inputs[i] = input;
        }
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(state, operand, LibOpEqualTo.referenceFn, LibOpEqualTo.integrity, LibOpEqualTo.run, inputs);
    }

    /// Test the eval of greater than opcode parsed from a string. Tests 2
    /// inputs. Both inputs are 0.
    function testOpEqualToEval2ZeroInputs() external view {
        checkHappy("_: equal-to(0 0);", bytes32(uint256(1)), "");
    }

    /// Test the eval of greater than opcode parsed from a string. Tests 2
    /// inputs. The first input is 0, the second input is 1.
    function testOpEqualToEval2InputsFirstZeroSecondOne() external view {
        checkHappy("_: equal-to(0 1);", 0, "");
    }

    /// Test the eval of greater than opcode parsed from a string. Tests 2
    /// inputs. The first input is 1, the second input is 0.
    function testOpEqualToEval2InputsFirstOneSecondZero() external view {
        checkHappy("_: equal-to(1 0);", 0, "");
    }

    /// Test the eval of greater than opcode parsed from a string. Tests 2
    /// inputs. Both inputs are 1.
    function testOpEqualToEval2InputsBothOne() external view {
        checkHappy("_: equal-to(1 1);", bytes32(uint256(1)), "");
    }

    /// A few examples of different exponents with the same numerical value.
    function testOpEqualToEval2Inputs() external view {
        checkHappy("_: equal-to(1 1e0);", bytes32(uint256(1)), "");
        checkHappy("_: equal-to(10 10e0);", bytes32(uint256(1)), "");
        checkHappy("_: equal-to(1e1 10);", bytes32(uint256(1)), "");
        checkHappy("_: equal-to(0.2 2e-1);", bytes32(uint256(1)), "");
        checkHappy("_: equal-to(100e5 10e6);", bytes32(uint256(1)), "");
        checkHappy("_: equal-to(0x01 1);", bytes32(uint256(1)), "");
        checkHappy("_: equal-to(0x01 10e-1);", bytes32(uint256(1)), "");
    }

    /// Test the eval of equal to opcode parsed from a string. Tests 3 inputs
    /// that are all equal to each other.
    function testOpEqualToEval3InputsAllEqual() external view {
        checkHappy("_: equal-to(1 1 1);", bytes32(uint256(1)), "");
    }

    /// Test the eval of equal to opcode parsed from a string. Tests 3 inputs
    /// where the first two are equal but the third is not. Equality of a
    /// prefix is not enough.
    function testOpEqualToEval3InputsLastDiffers() external view {
        checkHappy("_: equal-to(1 1 2);", 0, "");
    }

    /// Test the eval of equal to opcode parsed from a string. Tests 3 inputs
    /// where the last two are equal but the first is not. The comparison must
    /// not skip the first input.
    function testOpEqualToEval3InputsFirstDiffers() external view {
        checkHappy("_: equal-to(2 1 1);", 0, "");
    }

    /// Test the eval of equal to opcode parsed from a string. Tests 3 inputs
    /// where the outer two are equal but the middle is not. The comparison
    /// must not be limited to the first and last inputs.
    ///
    /// Unlike the ordering comparisons, `equal-to` has NO case that separates
    /// chained adjacent pairs from comparing every input against the first:
    /// the two agree for every input whenever equality is transitive, and
    /// `LibDecimalFloat.eq` routes through `compareRescale`, which saturates
    /// rather than wraps. So this file pins the behaviour but cannot pin the
    /// reading, and nothing here would fail if the implementation switched.
    function testOpEqualToEval3InputsMiddleDiffers() external view {
        checkHappy("_: equal-to(1 2 1);", 0, "");
    }

    /// Test the eval of equal to opcode parsed from a string. Tests the
    /// maximum 15 inputs, all equal to each other.
    function testOpEqualToEval15InputsAllEqual() external view {
        checkHappy("_: equal-to(1 1 1 1 1 1 1 1 1 1 1 1 1 1 1);", bytes32(uint256(1)), "");
    }

    /// Test the eval of equal to opcode parsed from a string. Tests the
    /// maximum 15 inputs, where only the last one differs.
    function testOpEqualToEval15InputsLastDiffers() external view {
        checkHappy("_: equal-to(1 1 1 1 1 1 1 1 1 1 1 1 1 1 2);", 0, "");
    }

    /// Equality is numerical, not binary, for more than two inputs as well.
    function testOpEqualToEval3InputsDifferentExponents() external view {
        checkHappy("_: equal-to(1 1e0 10e-1);", bytes32(uint256(1)), "");
        checkHappy("_: equal-to(100e5 10e6 1e7);", bytes32(uint256(1)), "");
        checkHappy("_: equal-to(0x01 1 1.0);", bytes32(uint256(1)), "");
    }

    /// Test that an equal to without inputs fails integrity check.
    function testOpEqualToEvalFail0Inputs() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 0, 2, 0));
        bytes memory bytecode = I_DEPLOYER.parse2("_: equal-to();");
        (bytecode);
    }

    /// Test that an equal to with 1 input fails integrity check.
    function testOpEqualToEvalFail1Input() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 1, 2, 1));
        bytes memory bytecode = I_DEPLOYER.parse2("_: equal-to(0x00);");
        (bytecode);
    }

    function testOpEqualToZeroOutputs() external {
        checkBadOutputs(": equal-to(0 0);", 2, 1, 0);
    }

    function testOpEqualToTwoOutputs() external {
        checkBadOutputs("_ _: equal-to(0 0);", 2, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpEqualToEvalOperandDisallowed() external {
        checkUnhappyParse("_: equal-to<0>(1 2);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }

    /// 16 inputs overflows the 4 bit input nybble of the opcode io byte, so the
    /// parser rejects it. 15 inputs is the maximum.
    function testOpEqualToEvalFail16Inputs() external {
        bytes memory rainlang = bytes("_: equal-to(1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1);");
        vm.expectRevert(abi.encodeWithSelector(OpcodeIOOverflow.selector, LibParseError.tagErrorOffset(44)));
        I_PARSER.unsafeParse(rainlang);
    }
}
