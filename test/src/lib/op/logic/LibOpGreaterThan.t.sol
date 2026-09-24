// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpGreaterThan} from "../../../../../src/lib/op/logic/LibOpGreaterThan.sol";
import {IntegrityCheckState, BadOpInputsLength} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {Float, LibDecimalFloat} from "rain-math-float-0.2.1/src/lib/LibDecimalFloat.sol";
import {OpcodeIOOverflow} from "../../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../../src/lib/parse/LibParseError.sol";

contract LibOpGreaterThanTest is OpTest {
    /// Directly test the integrity logic of LibOpGreaterThan. The calc inputs
    /// must match the operand inputs, and the calc outputs must be 1.
    function testOpGreaterThanIntegrityHappy(
        IntegrityCheckState memory state,
        uint8 inputs,
        uint8 outputs,
        uint16 operandData
    ) external pure {
        inputs = uint8(bound(inputs, 2, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpGreaterThan.integrity(state, LibOperand.build(inputs, outputs, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpGreaterThan. This tests the
    /// unhappy path where the operand is invalid due to 0 inputs.
    function testOpGreaterThanIntegrityUnhappyZeroInputs(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpGreaterThan.integrity(state, OperandV2.wrap(0));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpGreaterThan. This tests the
    /// unhappy path where the operand is invalid due to 1 input.
    function testOpGreaterThanIntegrityUnhappyOneInput(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpGreaterThan.integrity(state, OperandV2.wrap(bytes32(uint256(0x010000))));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpGreaterThan.
    function testOpGreaterThanRun(StackItem input1, StackItem input2) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = input1;
        inputs[1] = input2;
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(
            state, operand, LibOpGreaterThan.referenceFn, LibOpGreaterThan.integrity, LibOpGreaterThan.run, inputs
        );
    }

    /// Directly test the runtime logic of LibOpGreaterThan for an arbitrary
    /// number of inputs.
    function testOpGreaterThanRunVariadic(StackItem[] memory inputs) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.assume(inputs.length >= 2);
        vm.assume(inputs.length <= 0x0F);
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(
            state, operand, LibOpGreaterThan.referenceFn, LibOpGreaterThan.integrity, LibOpGreaterThan.run, inputs
        );
    }

    /// Directly test the runtime logic of LibOpGreaterThan for an arbitrary
    /// number of strictly descending inputs. Random inputs almost never
    /// descend, so this covers the branch where the whole chain holds.
    function testOpGreaterThanRunVariadicDescending(uint8 length) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        length = uint8(bound(length, 2, 0x0F));
        StackItem[] memory inputs = new StackItem[](length);
        for (uint256 i = 0; i < inputs.length; i++) {
            // Exponent is fixed so the coefficient alone orders the inputs.
            // forge-lint: disable-next-line(unsafe-typecast)
            inputs[i] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(int256(inputs.length - i), 0)));
        }
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(
            state, operand, LibOpGreaterThan.referenceFn, LibOpGreaterThan.integrity, LibOpGreaterThan.run, inputs
        );
    }

    /// Test the eval of greater than opcode parsed from a string. Tests 2
    /// inputs. Both inputs are 0.
    function testOpGreaterThanEval2ZeroInputs() external view {
        checkHappy("_: greater-than(0 0);", 0, "");
    }

    /// Test the eval of greater than opcode parsed from a string. Tests 2
    /// inputs. The first input is 0, the second input is 1.
    function testOpGreaterThanEval2InputsFirstZeroSecondOne() external view {
        checkHappy("_: greater-than(0 1);", 0, "");
    }

    /// Test the eval of greater than opcode parsed from a string. Tests 2
    /// inputs. The first input is 1, the second input is 0.
    function testOpGreaterThanEval2InputsFirstOneSecondZero() external view {
        checkHappy("_: greater-than(1 0);", bytes32(uint256(1)), "");
    }

    /// Test the eval of greater than opcode parsed from a string. Tests 2
    /// inputs. Both inputs are 1.
    function testOpGreaterThanEval2InputsBothOne() external view {
        checkHappy("_: greater-than(1 1);", 0, "");
    }

    /// Test 1.1 gt 1.2, which should return 0.
    function testOpGreaterThanEval1_1Gt1_2() external view {
        checkHappy("_: greater-than(1.1 1.2);", 0, "");
    }

    /// Test 1.0 gt 1 which should return 0.
    function testOpGreaterThanEval1_0Gt1() external view {
        checkHappy("_: greater-than(1.0 1);", 0, "");
    }

    /// Test -1.1 gt -1.2, which should return 1.
    function testOpGreaterThanEvalNeg1_1GtNeg1_2() external view {
        checkHappy("_: greater-than(-1.1 -1.2);", bytes32(uint256(1)), "");
    }

    /// Test -1 gt 0, which should return 0.
    function testOpGreaterThanEvalNeg1Gt0() external view {
        checkHappy("_: greater-than(-1 0);", 0, "");
    }

    /// Test the eval of greater than opcode parsed from a string. Tests 3
    /// strictly descending inputs, which chain as `2 > 1 > 0`.
    function testOpGreaterThanEval3InputsDescending() external view {
        checkHappy("_: greater-than(2 1 0);", bytes32(uint256(1)), "");
    }

    /// Test the eval of greater than opcode parsed from a string. Tests 3
    /// inputs where the first pair descends but the second does not.
    function testOpGreaterThanEval3InputsLastPairNotDescending() external view {
        checkHappy("_: greater-than(2 1 1);", 0, "");
    }

    /// Test the eval of greater than opcode parsed from a string. Tests 3
    /// inputs where the second pair descends but the first does not. The chain
    /// must not skip the first pair.
    function testOpGreaterThanEval3InputsFirstPairNotDescending() external view {
        checkHappy("_: greater-than(1 1 0);", 0, "");
    }

    /// Test the eval of greater than opcode parsed from a string. Tests 3
    /// inputs where only the outer pair descends. The chain must compare
    /// adjacent inputs, not just the first and last.
    function testOpGreaterThanEval3InputsOnlyOuterDescending() external view {
        checkHappy("_: greater-than(2 0 1);", 0, "");
    }

    /// Test the eval of greater than opcode parsed from a string. Tests 3
    /// strictly ascending inputs.
    function testOpGreaterThanEval3InputsAscending() external view {
        checkHappy("_: greater-than(0 1 2);", 0, "");
    }

    /// Test the eval of greater than opcode parsed from a string. Tests the
    /// maximum 15 strictly descending inputs.
    function testOpGreaterThanEval15InputsDescending() external view {
        checkHappy("_: greater-than(14 13 12 11 10 9 8 7 6 5 4 3 2 1 0);", bytes32(uint256(1)), "");
    }

    /// Test the eval of greater than opcode parsed from a string. Tests the
    /// maximum 15 inputs where only the final pair breaks the chain.
    function testOpGreaterThanEval15InputsLastPairNotDescending() external view {
        checkHappy("_: greater-than(14 13 12 11 10 9 8 7 6 5 4 3 2 1 1);", 0, "");
    }

    /// Test that a greater than without inputs fails integrity check.
    function testOpGreaterThanEvalFail0Inputs() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 0, 2, 0));
        bytes memory bytecode = I_DEPLOYER.parse2("_: greater-than();");
        (bytecode);
    }

    /// Test that a greater than with 1 input fails integrity check.
    function testOpGreaterThanEvalFail1Input() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 1, 2, 1));
        bytes memory bytecode = I_DEPLOYER.parse2("_: greater-than(0x00);");
        (bytecode);
    }

    function testOpGreaterThanZeroOutputs() external {
        checkBadOutputs(": greater-than(1 2);", 2, 1, 0);
    }

    function testOpGreaterThanTwoOutputs() external {
        checkBadOutputs("_ _: greater-than(1 2);", 2, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpGreaterThanEvalOperandDisallowed() external {
        checkUnhappyParse("_: greater-than<0>(1 2);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }

    /// 16 inputs overflows the 4 bit input nybble of the opcode io byte, so the
    /// parser rejects it. 15 inputs is the maximum.
    function testOpGreaterThanEvalFail16Inputs() external {
        bytes memory rainlang = bytes("_: greater-than(1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1);");
        vm.expectRevert(abi.encodeWithSelector(OpcodeIOOverflow.selector, LibParseError.tagErrorOffset(48)));
        I_PARSER.unsafeParse(rainlang);
    }
}
