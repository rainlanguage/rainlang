// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpGreaterThanOrEqualTo} from "../../../../../src/lib/op/logic/LibOpGreaterThanOrEqualTo.sol";
import {IntegrityCheckState, BadOpInputsLength} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {Float, LibDecimalFloat} from "rain-math-float-0.2.1/src/lib/LibDecimalFloat.sol";
import {OpcodeIOOverflow} from "../../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../../src/lib/parse/LibParseError.sol";

contract LibOpGreaterThanOrEqualToTest is OpTest {
    /// Directly test the integrity logic of LibOpGreaterThanOrEqualTo. The calc
    /// inputs must match the operand inputs, and the calc outputs must be 1.
    function testOpGreaterThanOrEqualToIntegrityHappy(
        IntegrityCheckState memory state,
        uint8 inputs,
        uint8 outputs,
        uint16 operandData
    ) external pure {
        inputs = uint8(bound(inputs, 2, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpGreaterThanOrEqualTo.integrity(state, LibOperand.build(inputs, outputs, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpGreaterThanOrEqualTo. This
    /// tests the unhappy path where the operand is invalid due to 0 inputs.
    function testOpGreaterThanOrEqualToIntegrityUnhappyZeroInputs(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpGreaterThanOrEqualTo.integrity(state, OperandV2.wrap(0));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpGreaterThanOrEqualTo. This
    /// tests the unhappy path where the operand is invalid due to 1 input.
    function testOpGreaterThanOrEqualToIntegrityUnhappyOneInput(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpGreaterThanOrEqualTo.integrity(state, OperandV2.wrap(bytes32(uint256(0x010000))));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpGreaterThanOrEqualTo.
    function testOpGreaterThanOrEqualToRun(StackItem input1, StackItem input2) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = input1;
        inputs[1] = input2;
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(
            state,
            operand,
            LibOpGreaterThanOrEqualTo.referenceFn,
            LibOpGreaterThanOrEqualTo.integrity,
            LibOpGreaterThanOrEqualTo.run,
            inputs
        );
    }

    /// Directly test the runtime logic of LibOpGreaterThanOrEqualTo for an
    /// arbitrary number of inputs.
    function testOpGreaterThanOrEqualToRunVariadic(StackItem[] memory inputs) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.assume(inputs.length >= 2);
        vm.assume(inputs.length <= 0x0F);
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(
            state,
            operand,
            LibOpGreaterThanOrEqualTo.referenceFn,
            LibOpGreaterThanOrEqualTo.integrity,
            LibOpGreaterThanOrEqualTo.run,
            inputs
        );
    }

    /// Directly test the runtime logic of LibOpGreaterThanOrEqualTo for an
    /// arbitrary number of descending inputs. Random inputs almost never
    /// descend, so this covers the branch where the whole chain holds.
    function testOpGreaterThanOrEqualToRunVariadicDescending(uint8 length) external view {
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
            state,
            operand,
            LibOpGreaterThanOrEqualTo.referenceFn,
            LibOpGreaterThanOrEqualTo.integrity,
            LibOpGreaterThanOrEqualTo.run,
            inputs
        );
    }

    /// Test the eval of greater than or equal to opcode parsed from a string.
    /// Tests 2 inputs. Both inputs are 0.
    function testOpGreaterThanOrEqualToEval2ZeroInputs() external view {
        checkHappy("_: greater-than-or-equal-to(0 0);", bytes32(uint256(1)), "");
    }

    /// Test the eval of greater than or equal to opcode parsed from a string.
    /// Tests 2 inputs. The first input is 0, the second input is 1.
    function testOpGreaterThanOrEqualToEval2InputsFirstZeroSecondOne() external view {
        checkHappy("_: greater-than-or-equal-to(0 1);", 0, "");
    }

    /// Test the eval of greater than or equal to opcode parsed from a string.
    /// Tests 2 inputs. The first input is 1, the second input is 0.
    function testOpGreaterThanOrEqualToEval2InputsFirstOneSecondZero() external view {
        checkHappy("_: greater-than-or-equal-to(1 0);", bytes32(uint256(1)), "");
    }

    /// Test the eval of greater than or equal to opcode parsed from a string.
    /// Tests 2 inputs. Both inputs are 1.
    function testOpGreaterThanOrEqualToEval2InputsBothOne() external view {
        checkHappy("_: greater-than-or-equal-to(1 1);", bytes32(uint256(1)), "");
    }

    /// Test 1.1 >= 1.2, which should return 0.
    function testOpGreaterThanOrEqualToEvalOnePointOneGteOnePointTwo() external view {
        checkHappy("_: greater-than-or-equal-to(1.1 1.2);", 0, "");
    }

    /// Test 1.0 >= 1, which should return 1 (equal).
    function testOpGreaterThanOrEqualToEvalOnePointZeroGteOne() external view {
        checkHappy("_: greater-than-or-equal-to(1.0 1);", bytes32(uint256(1)), "");
    }

    /// Test -1.1 >= -1.2, which should return 1.
    function testOpGreaterThanOrEqualToEvalNegOnePointOneGteNegOnePointTwo() external view {
        checkHappy("_: greater-than-or-equal-to(-1.1 -1.2);", bytes32(uint256(1)), "");
    }

    /// Test -1 >= 0, which should return 0.
    function testOpGreaterThanOrEqualToEvalNegOneGteZero() external view {
        checkHappy("_: greater-than-or-equal-to(-1 0);", 0, "");
    }

    /// Test the eval of greater than or equal to opcode parsed from a string.
    /// Tests 3 inputs, which chain as `2 >= 1 >= 0`.
    function testOpGreaterThanOrEqualToEval3InputsDescending() external view {
        checkHappy("_: greater-than-or-equal-to(2 1 0);", bytes32(uint256(1)), "");
    }

    /// Test the eval of greater than or equal to opcode parsed from a string.
    /// Tests 3 equal inputs, which satisfy the chain because the comparison is
    /// not strict.
    function testOpGreaterThanOrEqualToEval3InputsAllEqual() external view {
        checkHappy("_: greater-than-or-equal-to(1 1 1);", bytes32(uint256(1)), "");
    }

    /// Test the eval of greater than or equal to opcode parsed from a string.
    /// Tests 3 inputs where the first pair descends but the second does not.
    function testOpGreaterThanOrEqualToEval3InputsLastPairAscends() external view {
        checkHappy("_: greater-than-or-equal-to(2 1 2);", 0, "");
    }

    /// Test the eval of greater than or equal to opcode parsed from a string.
    /// Tests 3 inputs where the second pair descends but the first does not.
    /// The chain must not skip the first pair.
    function testOpGreaterThanOrEqualToEval3InputsFirstPairAscends() external view {
        checkHappy("_: greater-than-or-equal-to(0 1 0);", 0, "");
    }

    /// Test the eval of greater than or equal to opcode parsed from a string.
    /// Tests 3 inputs where only the outer pair is ordered.
    ///
    /// The case that separates the two readings, so the expected value is
    /// derived rather than observed:
    ///
    /// - chained, as Clojure's `(>= 2 0 1)` does, expands to
    ///   `2 >= 0 && 0 >= 1` = **false**;
    /// - every input against the first expands to `2 >= 0 && 2 >= 1` = **true**.
    ///
    /// A `1` here would mean the second reading had been adopted silently.
    function testOpGreaterThanOrEqualToEval3InputsOnlyOuterOrdered() external view {
        checkHappy("_: greater-than-or-equal-to(2 0 1);", 0, "");
    }

    /// Test the eval of greater than or equal to opcode parsed from a string.
    /// Tests the maximum 15 descending inputs.
    function testOpGreaterThanOrEqualToEval15InputsDescending() external view {
        checkHappy("_: greater-than-or-equal-to(14 13 12 11 10 9 8 7 6 5 4 3 2 1 0);", bytes32(uint256(1)), "");
    }

    /// Test the eval of greater than or equal to opcode parsed from a string.
    /// Tests the maximum 15 inputs where only the final pair breaks the chain.
    function testOpGreaterThanOrEqualToEval15InputsLastPairAscends() external view {
        checkHappy("_: greater-than-or-equal-to(14 13 12 11 10 9 8 7 6 5 4 3 2 1 2);", 0, "");
    }

    /// Test that a greater than or equal to without inputs fails integrity check.
    function testOpGreaterThanOrEqualToEvalFail0Inputs() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 0, 2, 0));
        bytes memory bytecode = I_DEPLOYER.parse2("_: greater-than-or-equal-to();");
        (bytecode);
    }

    /// Test that a greater than or equal to with 1 input fails integrity check.
    function testOpGreaterThanOrEqualToEvalFail1Input() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 1, 2, 1));
        bytes memory bytecode = I_DEPLOYER.parse2("_: greater-than-or-equal-to(0x00);");
        (bytecode);
    }

    function testOpGreaterThanOrEqualToZeroOutputs() external {
        checkBadOutputs(": greater-than-or-equal-to(1 2);", 2, 1, 0);
    }

    function testOpGreaterThanOrEqualToTwoOutputs() external {
        checkBadOutputs("_ _: greater-than-or-equal-to(1 2);", 2, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpGreaterThanOrEqualToEvalOperandDisallowed() external {
        checkUnhappyParse("_: greater-than-or-equal-to<0>(1 2);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }

    /// 16 inputs overflows the 4 bit input nybble of the opcode io byte, so the
    /// parser rejects it. 15 inputs is the maximum.
    function testOpGreaterThanOrEqualToEvalFail16Inputs() external {
        bytes memory rainlang = bytes("_: greater-than-or-equal-to(1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1);");
        vm.expectRevert(abi.encodeWithSelector(OpcodeIOOverflow.selector, LibParseError.tagErrorOffset(60)));
        I_PARSER.unsafeParse(rainlang);
    }
}
