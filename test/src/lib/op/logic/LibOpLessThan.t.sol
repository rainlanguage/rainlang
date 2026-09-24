// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpLessThan} from "../../../../../src/lib/op/logic/LibOpLessThan.sol";
import {OperandV2, StackItem} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {IntegrityCheckState, BadOpInputsLength} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {Float, LibDecimalFloat} from "rain-math-float-0.2.1/src/lib/LibDecimalFloat.sol";
import {OpcodeIOOverflow} from "../../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../../src/lib/parse/LibParseError.sol";

contract LibOpLessThanTest is OpTest {
    /// Directly test the integrity logic of LibOpLessThan. The calc inputs must
    /// match the operand inputs, and the calc outputs must be 1.
    function testOpLessThanIntegrityHappy(
        IntegrityCheckState memory state,
        uint8 inputs,
        uint8 outputs,
        uint16 operandData
    ) external pure {
        inputs = uint8(bound(inputs, 2, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpLessThan.integrity(state, LibOperand.build(inputs, outputs, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpLessThan. This tests the
    /// unhappy path where the operand is invalid due to 0 inputs.
    function testOpLessThanIntegrityUnhappyZeroInputs(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpLessThan.integrity(state, OperandV2.wrap(0));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpLessThan. This tests the
    /// unhappy path where the operand is invalid due to 1 input.
    function testOpLessThanIntegrityUnhappyOneInput(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpLessThan.integrity(state, OperandV2.wrap(bytes32(uint256(0x010000))));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpLessThan.
    function testOpLessThanRun(StackItem input1, StackItem input2) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = input1;
        inputs[1] = input2;
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(state, operand, LibOpLessThan.referenceFn, LibOpLessThan.integrity, LibOpLessThan.run, inputs);
    }

    /// Directly test the runtime logic of LibOpLessThan for an arbitrary number
    /// of inputs.
    function testOpLessThanRunVariadic(StackItem[] memory inputs) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.assume(inputs.length >= 2);
        vm.assume(inputs.length <= 0x0F);
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(state, operand, LibOpLessThan.referenceFn, LibOpLessThan.integrity, LibOpLessThan.run, inputs);
    }

    /// Directly test the runtime logic of LibOpLessThan for an arbitrary number
    /// of strictly ascending inputs. Random inputs almost never ascend, so this
    /// covers the branch where the whole chain holds.
    function testOpLessThanRunVariadicAscending(uint8 length) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        length = uint8(bound(length, 2, 0x0F));
        StackItem[] memory inputs = new StackItem[](length);
        for (uint256 i = 0; i < inputs.length; i++) {
            // Exponent is fixed so the coefficient alone orders the inputs.
            // forge-lint: disable-next-line(unsafe-typecast)
            inputs[i] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(int256(i), 0)));
        }
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(state, operand, LibOpLessThan.referenceFn, LibOpLessThan.integrity, LibOpLessThan.run, inputs);
    }

    /// Test the eval of less than opcode parsed from a string. Tests 2 inputs.
    /// Both inputs are 0.
    function testOpLessThanEval2ZeroInputs() external view {
        checkHappy("_: less-than(0 0);", 0, "");
    }

    /// Test the eval of less than opcode parsed from a string. Tests 2 inputs.
    /// The first input is 0, the second input is 1.
    function testOpLessThanEval2InputsFirstZeroSecondOne() external view {
        checkHappy("_: less-than(0 1);", bytes32(uint256(1)), "");
    }

    /// Test the eval of less than opcode parsed from a string. Tests 2 inputs.
    /// The first input is 1, the second input is 0.
    function testOpLessThanEval2InputsFirstOneSecondZero() external view {
        checkHappy("_: less-than(1 0);", bytes32(uint256(0)), "");
    }

    /// Test the eval of less than opcode parsed from a string. Tests 2 inputs.
    /// Both inputs are 1.
    function testOpLessThanEval2InputsBothOne() external view {
        checkHappy("_: less-than(1 1);", bytes32(uint256(0)), "");
    }

    // Test 1.1 lt 1.2, which should return 1.
    function testOpLessThan1_1Lt1_2() external view {
        checkHappy("_: less-than(1.1 1.2);", bytes32(uint256(1)), "");
    }

    /// Test 1.0 lt 1 which should return 0.
    function testOpLessThan1_0Lt1() external view {
        checkHappy("_: less-than(1.0 1);", bytes32(uint256(0)), "");
    }

    // Test -1.1 lt -1.2, which should return 0.
    function testOpLessThanMinus1_1LtMinus1_2() external view {
        checkHappy("_: less-than(-1.1 -1.2);", bytes32(uint256(0)), "");
    }

    /// Test -1 lt 0, which should return 1.
    function testOpLessThanMinus1Lt0() external view {
        checkHappy("_: less-than(-1 0);", bytes32(uint256(1)), "");
    }

    /// Test the eval of less than opcode parsed from a string. Tests 3
    /// strictly ascending inputs, which chain as `0 < 1 < 2`.
    function testOpLessThanEval3InputsAscending() external view {
        checkHappy("_: less-than(0 1 2);", bytes32(uint256(1)), "");
    }

    /// Test the eval of less than opcode parsed from a string. Tests 3 inputs
    /// where the first pair ascends but the second does not.
    function testOpLessThanEval3InputsLastPairNotAscending() external view {
        checkHappy("_: less-than(0 1 1);", 0, "");
    }

    /// Test the eval of less than opcode parsed from a string. Tests 3 inputs
    /// where the second pair ascends but the first does not. The chain must
    /// not skip the first pair.
    function testOpLessThanEval3InputsFirstPairNotAscending() external view {
        checkHappy("_: less-than(1 1 2);", 0, "");
    }

    /// Test the eval of less than opcode parsed from a string. Tests 3 inputs
    /// where only the outer pair ascends. The chain must compare adjacent
    /// inputs, not just the first and last.
    function testOpLessThanEval3InputsOnlyOuterAscending() external view {
        checkHappy("_: less-than(0 2 1);", 0, "");
    }

    /// Test the eval of less than opcode parsed from a string. Tests 3
    /// strictly descending inputs.
    function testOpLessThanEval3InputsDescending() external view {
        checkHappy("_: less-than(2 1 0);", 0, "");
    }

    /// Test the eval of less than opcode parsed from a string. Tests the
    /// maximum 15 strictly ascending inputs.
    function testOpLessThanEval15InputsAscending() external view {
        checkHappy("_: less-than(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14);", bytes32(uint256(1)), "");
    }

    /// Test the eval of less than opcode parsed from a string. Tests the
    /// maximum 15 inputs where only the final pair breaks the chain.
    function testOpLessThanEval15InputsLastPairNotAscending() external view {
        checkHappy("_: less-than(0 1 2 3 4 5 6 7 8 9 10 11 12 13 13);", 0, "");
    }

    /// Test that a less than to without inputs fails integrity check.
    function testOpLessThanToEvalFail0Inputs() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 0, 2, 0));
        bytes memory bytecode = I_DEPLOYER.parse2("_: less-than();");
        (bytecode);
    }

    /// Test that a less than to with 1 input fails integrity check.
    function testOpLessThanToEvalFail1Input() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 1, 2, 1));
        bytes memory bytecode = I_DEPLOYER.parse2("_: less-than(0x00);");
        (bytecode);
    }

    function testOpLessThanZeroOutputs() external {
        checkBadOutputs(": less-than(0 0);", 2, 1, 0);
    }

    function testOpLessThanTwoOutputs() external {
        checkBadOutputs("_ _: less-than(30 0);", 2, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpLessThanEvalOperandDisallowed() external {
        checkUnhappyParse("_: less-than<0>(1 2);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }

    /// 16 inputs overflows the 4 bit input nybble of the opcode io byte, so the
    /// parser rejects it. 15 inputs is the maximum.
    function testOpLessThanEvalFail16Inputs() external {
        bytes memory rainlang = bytes("_: less-than(1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1);");
        vm.expectRevert(abi.encodeWithSelector(OpcodeIOOverflow.selector, LibParseError.tagErrorOffset(45)));
        I_PARSER.unsafeParse(rainlang);
    }
}
