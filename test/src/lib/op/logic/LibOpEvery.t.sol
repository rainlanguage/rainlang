// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpEvery} from "../../../../../src/lib/op/logic/LibOpEvery.sol";
import {IntegrityCheckState, BadOpInputsLength} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";

contract LibOpEveryTest is OpTest {
    /// Directly test the integrity logic of LibOpEvery. This tests the happy
    /// path where the operand is valid.
    function testOpEveryIntegrityHappy(
        IntegrityCheckState memory state,
        uint8 inputs,
        uint8 outputs,
        uint16 operandData
    ) external pure {
        inputs = uint8(bound(inputs, 1, 0x0F));
        outputs = uint8(bound(outputs, 1, 0x0F));

        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpEvery.integrity(state, LibOperand.build(inputs, outputs, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpEvery. This tests the unhappy
    /// path where the operand is invalid due to 0 inputs.
    function testOpEveryIntegrityUnhappyZeroInputs(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpEvery.integrity(state, OperandV2.wrap(0));
        // Calc inputs will be minimum 1.
        assertEq(calcInputs, 1);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpEvery.
    function testOpEveryRun(StackItem[] memory inputs) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.assume(inputs.length != 0);
        vm.assume(inputs.length <= 0x0F);
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(state, operand, LibOpEvery.referenceFn, LibOpEvery.integrity, LibOpEvery.run, inputs);
    }

    /// Test the eval of every opcode parsed from a string. Tests 1 true input.
    function testOpEveryEval1TrueInput() external view {
        checkHappy("_: every(5);", Float.unwrap(LibDecimalFloat.packLossless(5, 0)), "");
    }

    /// Test the eval of every opcode parsed from a string. Tests 1 false input.
    function testOpEveryEval1FalseInput() external view {
        checkHappy("_: every(0);", 0, "");
    }

    /// Test the eval of every opcode parsed from a string. Tests 2 true inputs.
    /// The last true input should be the overall result.
    function testOpEveryEval2TrueInputs() external view {
        checkHappy("_: every(5 6);", Float.unwrap(LibDecimalFloat.packLossless(6, 0)), "");
    }

    /// Test the eval of every opcode parsed from a string. Tests 2 false inputs.
    function testOpEveryEval2FalseInputs() external view {
        checkHappy("_: every(0 0);", 0, "");
    }

    /// Test the eval of every opcode parsed from a string. Tests 2 inputs, one
    /// true and one false. The overall result is false.
    function testOpEveryEval2MixedInputs() external view {
        checkHappy("_: every(5 0);", 0, "");
    }

    /// Test the eval of every opcode parsed from a string. Tests 2 inputs, one
    /// true and one false. The overall result is false.
    function testOpEveryEval2MixedInputs2() external view {
        checkHappy("_: every(0 5);", 0, "");
    }

    /// zero with a non zero exponent is false.
    function testOpEveryEvalZeroWithExponent() external view {
        checkHappy("_: every(0e5 5);", 0, "");
    }

    /// Test that every without inputs fails integrity check.
    function testOpEveryEvalFail() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 0, 1, 0));
        bytes memory bytecode = I_DEPLOYER.parse2("_: every();");
        (bytecode);
    }

    function testOpEveryZeroOutputs() external {
        checkBadOutputs(": every(5);", 1, 1, 0);
    }

    function testOpEveryTwoOutputs() external {
        checkBadOutputs("_ _: every(5);", 1, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpEveryEvalOperandDisallowed() external {
        checkUnhappyParse("_: every<0>(1);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
