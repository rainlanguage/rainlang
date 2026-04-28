// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpConditions} from "../../../../../src/lib/op/logic/LibOpConditions.sol";
import {IntegrityCheckState, BadOpInputsLength} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibIntOrAString, IntOrAString} from "rain.intorastring/lib/LibIntOrAString.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {Float, LibDecimalFloat} from "rain.math.float/lib/LibDecimalFloat.sol";

contract LibOpConditionsTest is OpTest {
    using LibUint256Array for uint256[];
    using LibDecimalFloat for Float;

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
