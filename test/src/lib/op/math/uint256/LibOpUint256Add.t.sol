// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, IntegrityCheckState, OperandV2, InterpreterState, stdError} from "test/abstract/OpTest.sol";
import {LibOpUint256Add} from "../../../../../../src/lib/op/math/uint256/LibOpUint256Add.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

contract LibOpUint256AddTest is OpTest {
    /// Directly test the integrity logic of LibOpUint256Add. This tests the happy
    /// path where the inputs input and calc match.
    function testOpUint256AddIntegrityHappy(IntegrityCheckState memory state, uint8 inputs, uint16 operandData)
        external
        pure
    {
        inputs = uint8(bound(inputs, 2, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpUint256Add.integrity(state, LibOperand.build(inputs, 1, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpUint256Add. This tests the unhappy
    /// path where the operand is invalid due to 0 inputs.
    function testOpUint256AddIntegrityUnhappyZeroInputs(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpUint256Add.integrity(state, OperandV2.wrap(0));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpUint256Add. This tests the unhappy
    /// path where the operand is invalid due to 1 inputs.
    function testOpUint256AddIntegrityUnhappyOneInput(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpUint256Add.integrity(state, OperandV2.wrap(bytes32(uint256(0x010000))));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    function _testOpUint256AddRun(OperandV2 operand, StackItem[] memory inputs) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        opReferenceCheck(
            state, operand, LibOpUint256Add.referenceFn, LibOpUint256Add.integrity, LibOpUint256Add.run, inputs
        );
    }

    /// Directly test the runtime logic of LibOpUint256Add.
    function testOpUint256AddRun(StackItem[] memory inputs) external {
        vm.assume(inputs.length >= 2);
        vm.assume(inputs.length <= 0x0F);
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        uint256 overflows = 0;
        unchecked {
            uint256 a = uint256(StackItem.unwrap(inputs[0]));
            for (uint256 i = 1; i < inputs.length; i++) {
                uint256 b = uint256(StackItem.unwrap(inputs[i]));
                uint256 c = a + b;
                if (c < a) {
                    overflows++;
                }
                a = c;
            }
        }
        if (overflows > 0) {
            vm.expectRevert(stdError.arithmeticError);
        }
        this._testOpUint256AddRun(operand, inputs);
    }

    function testOpUint256AddEvalZeroInputs() external {
        checkBadInputs("_: uint256-add();", 0, 2, 0);
    }

    function testOpUint256AddEvalOneInput() external {
        checkBadInputs("_: uint256-add(0x05);", 1, 2, 1);
        checkBadInputs("_: uint256-add(0);", 1, 2, 1);
        checkBadInputs("_: uint256-add(0x01);", 1, 2, 1);
        checkBadInputs("_: uint256-add(uint256-max-value());", 1, 2, 1);
    }

    function testOpUint256AddEvalZeroOutputs() external {
        checkBadOutputs(": uint256-add(0 0);", 2, 1, 0);
    }

    function testOpUint256AddEvalTwoOutputs() external {
        checkBadOutputs("_ _: uint256-add(0 0);", 2, 1, 2);
    }

    function testOpUint256AddEvalTwoInputsHappy() external view {
        checkHappy("_: uint256-add(0x01 0x02);", bytes32(uint256(3)), "1 2");
        checkHappy("_: uint256-add(0x01 0x00);", bytes32(uint256(1)), "1 0");
        checkHappy("_: uint256-add(0x00 0x02);", bytes32(uint256(2)), "0 2");
        checkHappy("_: uint256-add(0x00 0x00);", bytes32(uint256(0)), "0 0");
        checkHappy("_: uint256-add(0x01 0x01);", bytes32(uint256(2)), "1 1");
        checkHappy("_: uint256-add(uint256-max-value() 0);", bytes32(type(uint256).max), "uint256-max-value() 0");
    }

    function testOpUint256AddEvalThreeInputsHappy() external view {
        checkHappy("_: uint256-add(0x01 0x02 0x03);", bytes32(uint256(6)), "1 2 3");
        checkHappy("_: uint256-add(0x01 0x00 0x00);", bytes32(uint256(1)), "1 0 0");
        checkHappy("_: uint256-add(0x00 0x02 0x00);", bytes32(uint256(2)), "0 2 0");
        checkHappy("_: uint256-add(0x00 0x00 0x00);", bytes32(uint256(0)), "0 0 0");
    }

    function testOpUint256AddEvalThreeInputsUnhappy() external {
        checkUnhappy("_: uint256-add(uint256-max-value() 0x03 0x04);", stdError.arithmeticError);
        checkUnhappy("_: uint256-add(0x01 uint256-max-value() uint256-max-value() 0x04);", stdError.arithmeticError);
    }

    function testOpUint256AddEvalOperandsDisallowed() external {
        checkDisallowedOperand("_: uint256-add<0>(0 0);");
        checkDisallowedOperand("_: uint256-add<1>(0 0);");
        checkDisallowedOperand("_: uint256-add<2>(0 0);");
        checkDisallowedOperand("_: uint256-add<0 0>(0 0);");
        checkDisallowedOperand("_: uint256-add<1 0>(0 0);");
        checkDisallowedOperand("_: uint256-add<0 1>(0 0);");
    }
}
