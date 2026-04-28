// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpUint256MaxValue} from "../../../../../../src/lib/op/math/uint256/LibOpUint256MaxValue.sol";
import {IntegrityCheckState, BadOpInputsLength} from "../../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState, LibInterpreterState} from "../../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";

/// @title LibOpUint256MaxValueTest
/// @notice Test the runtime and integrity time logic of LibOpUint256MaxValue.
contract LibOpUint256MaxValueTest is OpTest {
    using LibInterpreterState for InterpreterState;

    /// Directly test the integrity logic of LibOpUint256MaxValue.
    function testOpMaxUint256Integrity(
        IntegrityCheckState memory state,
        uint8 inputs,
        uint8 outputs,
        uint16 operandData
    ) external pure {
        inputs = uint8(bound(inputs, 0, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpUint256MaxValue.integrity(state, LibOperand.build(inputs, outputs, operandData));

        assertEq(calcInputs, 0);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpUint256MaxValue. This tests that the
    /// opcode correctly pushes the max uint256 onto the stack.
    function testOpMaxUint256Run() external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        StackItem[] memory inputs = new StackItem[](0);
        OperandV2 operand = LibOperand.build(0, 1, 0);
        opReferenceCheck(
            state,
            operand,
            LibOpUint256MaxValue.referenceFn,
            LibOpUint256MaxValue.integrity,
            LibOpUint256MaxValue.run,
            inputs
        );
    }

    /// Test the eval of LibOpUint256MaxValue parsed from a string.
    function testOpMaxUint256Eval() external view {
        checkHappy("_: uint256-max-value();", bytes32(type(uint256).max), "");
    }

    /// Test that a max-value with inputs fails integrity check.
    function testOpMaxUint256EvalFail() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 1, 0, 1));
        bytes memory bytecode = I_DEPLOYER.parse2("_: uint256-max-value(0x00);");
        (bytecode);
    }

    function testOpMaxUint256ZeroOutputs() external {
        checkBadOutputs(": uint256-max-value();", 0, 1, 0);
    }

    function testOpMaxUint256TwoOutputs() external {
        checkBadOutputs("_ _: uint256-max-value();", 0, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpMaxUint256EvalOperandDisallowed() external {
        checkUnhappyParse("_: uint256-max-value<0>();", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
