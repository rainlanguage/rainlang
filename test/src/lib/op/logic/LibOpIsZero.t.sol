// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {IntegrityCheckState, BadOpInputsLength} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {LibOpIsZero} from "../../../../../src/lib/op/logic/LibOpIsZero.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";

contract LibOpIsZeroTest is OpTest {
    /// Directly test the integrity logic of LibOpIsZero. This tests the happy
    /// path where the operand is valid. IsZero is a 1 input, 1 output op.
    function testOpIsZeroIntegrityHappy(
        IntegrityCheckState memory state,
        uint8 inputs,
        uint8 outputs,
        uint16 operandData
    ) external pure {
        inputs = uint8(bound(inputs, 1, 0x0F));
        outputs = uint8(bound(outputs, 1, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpIsZero.integrity(state, LibOperand.build(inputs, outputs, operandData));

        // The inputs from the operand are ignored. The op is always 1 input.
        assertEq(calcInputs, 1);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpIsZero.
    function testOpIsZeroRun(StackItem input) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = input;
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(state, operand, LibOpIsZero.referenceFn, LibOpIsZero.integrity, LibOpIsZero.run, inputs);
    }

    /// Test the eval of isZero opcode parsed from a string. Tests 1 nonzero input.
    function testOpIsZeroEval1NonZeroInput() external view {
        checkHappy("_: is-zero(30);", 0, "");
    }

    /// Test the eval of isZero opcode parsed from a string. Tests 1 zero input.
    function testOpIsZeroEval1ZeroInput() external view {
        checkHappy("_: is-zero(0);", bytes32(uint256(1)), "");
    }

    /// Test 0e20 eval of isZero opcode parsed from a string. Tests 1 zero input.
    function testOpIsZeroEval0e20Input() external view {
        checkHappy("_: is-zero(0e20);", bytes32(uint256(1)), "");
    }

    /// Test that an iszero without inputs fails integrity check.
    function testOpIsZeroEvalFail0Inputs() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 0, 1, 0));
        bytes memory bytecode = I_DEPLOYER.parse2("_: is-zero();");
        (bytecode);
    }

    /// Test that an iszero with 2 inputs fails integrity check.
    function testOpIsZeroEvalFail2Inputs() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 2, 1, 2));
        bytes memory bytecode = I_DEPLOYER.parse2("_: is-zero(0x00 0x00);");
        (bytecode);
    }

    function testOpIsZeroZeroOutputs() external {
        checkBadOutputs(": is-zero(0);", 1, 1, 0);
    }

    function testOpIsZeroTwoOutputs() external {
        checkBadOutputs("_ _: is-zero(30);", 1, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpIsZeroEvalOperandDisallowed() external {
        checkUnhappyParse("_: is-zero<0>(1);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
