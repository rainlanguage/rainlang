// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpMaxNegativeValue} from "../../../../../src/lib/op/math/LibOpMaxNegativeValue.sol";
import {IntegrityCheckState, BadOpInputsLength} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState, LibInterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {Float, LibDecimalFloat} from "rain.math.float/lib/LibDecimalFloat.sol";

/// @title LibOpMaxNegativeValueTest
/// @notice Test the runtime and integrity time logic of LibOpMaxNegativeValue.
contract LibOpMaxNegativeValueTest is OpTest {
    using LibInterpreterState for InterpreterState;
    using LibDecimalFloat for Float;

    /// Directly test the integrity logic of LibOpMaxNegativeValue.
    function testOpMaxValueIntegrity(IntegrityCheckState memory state, uint8 inputs, uint8 outputs, uint16 operandData)
        external
        pure
    {
        inputs = uint8(bound(inputs, 0, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpMaxNegativeValue.integrity(state, LibOperand.build(inputs, outputs, operandData));

        assertEq(calcInputs, 0);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpMaxNegativeValue. This tests that
    /// the opcode correctly pushes the max value onto the stack.
    function testOpMaxNegativeValueRun() external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        StackItem[] memory inputs = new StackItem[](0);
        OperandV2 operand = LibOperand.build(0, 1, 0);
        opReferenceCheck(
            state,
            operand,
            LibOpMaxNegativeValue.referenceFn,
            LibOpMaxNegativeValue.integrity,
            LibOpMaxNegativeValue.run,
            inputs
        );
    }

    /// Test the eval of LibOpMaxNegativeValue parsed from a string.
    function testOpMaxNegativeValueEval() external view {
        checkHappy("_: max-negative-value();", Float.unwrap(LibDecimalFloat.FLOAT_MAX_NEGATIVE_VALUE), "");
    }

    /// Test that a max-negative-value with inputs fails integrity check.
    function testOpMaxNegativeValueEvalFail() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 1, 0, 1));
        bytes memory bytecode = I_DEPLOYER.parse2("_: max-negative-value(0x00);");
        (bytecode);
    }

    function testOpMaxNegativeValueZeroOutputs() external {
        checkBadOutputs(": max-negative-value();", 0, 1, 0);
    }

    function testOpMaxNegativeValueTwoOutputs() external {
        checkBadOutputs("_ _: max-negative-value();", 0, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpMaxNegativeValueEvalOperandDisallowed() external {
        checkUnhappyParse("_: max-negative-value<0>();", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
