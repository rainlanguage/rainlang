// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {stdError} from "forge-std/Test.sol";
import {OpTest} from "test/abstract/OpTest.sol";
import {LibOpUint256Power} from "../../../../../../src/lib/op/math/uint256/LibOpUint256Power.sol";
import {IntegrityCheckState} from "../../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {InterpreterState} from "../../../../../../src/lib/state/LibInterpreterState.sol";
import {StackItem, OperandV2} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";

contract LibOpUint256PowerTest is OpTest {
    /// Directly test the integrity logic of LibOpUint256Power. This tests the happy
    /// path where the inputs input and calc match.
    function testOpUint256ExpIntegrityHappy(IntegrityCheckState memory state, uint8 inputs, uint16 operandData)
        external
        pure
    {
        inputs = uint8(bound(inputs, 2, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpUint256Power.integrity(state, LibOperand.build(inputs, 1, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpUint256Power. This tests the unhappy
    /// path where the operand is invalid due to 0 inputs.
    function testOpUint256PowIntegrityUnhappyZeroInputs(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpUint256Power.integrity(state, OperandV2.wrap(0));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpUint256Power. This tests the unhappy
    /// path where the operand is invalid due to 1 inputs.
    function testOpUint256PowIntegrityUnhappyOneInput(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpUint256Power.integrity(state, OperandV2.wrap(bytes32(uint256(0x010000))));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    function _testOpUint256PowRun(OperandV2 operand, StackItem[] memory inputs) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        opReferenceCheck(
            state, operand, LibOpUint256Power.referenceFn, LibOpUint256Power.integrity, LibOpUint256Power.run, inputs
        );
    }

    /// Directly test the runtime logic of LibOpUint256Power.
    function testOpUint256PowRun(StackItem[] memory inputs) external {
        vm.assume(inputs.length >= 2);
        vm.assume(inputs.length <= 0x0F);
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        uint256 overflows = 0;
        unchecked {
            uint256 a = uint256(StackItem.unwrap(inputs[0]));
            for (uint256 i = 1; i < inputs.length; i++) {
                uint256 b = uint256(StackItem.unwrap(inputs[i]));
                if (b == 0) {
                    a = 1;
                    continue;
                } else if (b == 1 || a == 0) {
                    continue;
                } else {
                    uint256 c = a;
                    for (uint256 j = 1; j < b; j++) {
                        uint256 d = a * c;
                        if (d / c != a) {
                            overflows++;
                            break;
                        }
                        if (d == a) {
                            break;
                        }
                        a = d;
                    }
                }
            }
        }
        if (overflows > 0) {
            vm.expectRevert(stdError.arithmeticError);
        }
        this._testOpUint256PowRun(operand, inputs);
    }

    /// Test the eval of `uint256-power` opcode parsed from a string. Tests zero inputs.
    function testOpUint256PowEvalZeroInputs() external {
        checkBadInputs("_: uint256-power();", 0, 2, 0);
    }

    /// Test the eval of `uint256-power` opcode parsed from a string. Tests one input.
    function testOpUint256PowEvalOneInput() external {
        checkBadInputs("_: uint256-power(5e-18);", 1, 2, 1);
        checkBadInputs("_: uint256-power(0);", 1, 2, 1);
        checkBadInputs("_: uint256-power(1e-18);", 1, 2, 1);
        checkBadInputs("_: uint256-power(max-positive-value());", 1, 2, 1);
    }

    function testOpUint256PowEvalZeroOutputs() external {
        checkBadOutputs(": uint256-power(0 0);", 2, 1, 0);
    }

    function testOpUint256PowEvalTwoOutputs() external {
        checkBadOutputs("_ _: uint256-power(0 0);", 2, 1, 2);
    }

    /// Test the eval of `uint256-power` opcode parsed from a string. Tests two inputs.
    /// Tests the happy path where we do not overflow.
    function testOpUint256PowEval2InputsHappy() external view {
        // Anything exp 0 is 1.
        checkHappy("_: uint256-power(0 0);", bytes32(uint256(1)), "0 ** 0");
        checkHappy("_: uint256-power(0x01 0);", bytes32(uint256(1)), "1 ** 0");
        checkHappy("_: uint256-power(uint256-max-value() 0);", bytes32(uint256(1)), "uint256-max-value() ** 0");

        // 1 exp anything is 1.
        checkHappy("_: uint256-power(0x01 0);", bytes32(uint256(1)), "1 ** 0");
        checkHappy("_: uint256-power(0x01 0x01);", bytes32(uint256(1)), "1 ** 1");
        checkHappy("_: uint256-power(0x01 0x02);", bytes32(uint256(1)), "1 ** 2");
        checkHappy("_: uint256-power(0x01 0x03);", bytes32(uint256(1)), "1 ** 3");
        checkHappy("_: uint256-power(0x01 uint256-max-value());", bytes32(uint256(1)), "1 ** max-value()");

        // Anything exp 1 is itself.
        checkHappy("_: uint256-power(0 1);", 0, "0 ** 1");
        checkHappy("_: uint256-power(1 1);", bytes32(uint256(1)), "1 ** 1");
        checkHappy(
            "_: uint256-power(uint256-max-value() 0x01);", bytes32(type(uint256).max), "uint256-max-value() ** 1"
        );

        // Anything exp 2 is itself squared.
        checkHappy("_: uint256-power(0 0x02);", 0, "0 ** 2");
        checkHappy("_: uint256-power(0x01 0x02);", bytes32(uint256(1)), "1 ** 2");
        checkHappy("_: uint256-power(0x02 0x02);", bytes32(uint256(4)), "2 ** 2");
        checkHappy("_: uint256-power(0x03 0x02);", bytes32(uint256(9)), "3 ** 2");

        // Anything exp 3 is itself cubed.
        checkHappy("_: uint256-power(0 0x03);", 0, "0 ** 3");
        checkHappy("_: uint256-power(0x01 0x03);", bytes32(uint256(1)), "1 ** 3");
        checkHappy("_: uint256-power(0x02 0x03);", bytes32(uint256(8)), "2 ** 3");
        checkHappy("_: uint256-power(0x03 0x03);", bytes32(uint256(27)), "3 ** 3");
    }

    /// Test the eval of `uint256-power` opcode parsed from a string. Tests two inputs.
    /// Tests the unhappy path where we overflow.
    function testOpUint256PowEval2InputsUnhappy() external {
        checkUnhappy("_: uint256-power(0x02 uint256-max-value());", stdError.arithmeticError);
        checkUnhappy("_: uint256-power(0x03 uint256-max-value());", stdError.arithmeticError);
        checkUnhappy("_: uint256-power(uint256-max-value() uint256-max-value());", stdError.arithmeticError);
    }

    /// Test the eval of `uint256-power` opcode parsed from a string. Tests three inputs.
    /// Tests the happy path where we do not divide by zero.
    function testOpUint256PowEval3InputsHappy() external view {
        // Anything exp 0 is 1.
        checkHappy("_: uint256-power(0 0 0);", bytes32(uint256(1)), "0 ** 0 ** 0");
        checkHappy("_: uint256-power(0x01 0 0);", bytes32(uint256(1)), "1 ** 0 ** 0");
        checkHappy("_: uint256-power(uint256-max-value() 0 0);", bytes32(uint256(1)), "uint256-max-value() ** 0 ** 0");
        checkHappy("_: uint256-power(0 0x01 0);", bytes32(uint256(1)), "0 ** 1 ** 0");
        checkHappy("_: uint256-power(0x01 0x01 0);", bytes32(uint256(1)), "1 ** 1 ** 0");
        checkHappy("_: uint256-power(0 0 0x01);", bytes32(uint256(1)), "0 ** 0 ** 1");
        checkHappy("_: uint256-power(0x01 0 0x01);", bytes32(uint256(1)), "1 ** 0 ** 1");
        checkHappy(
            "_: uint256-power(uint256-max-value() 0 0x01);", bytes32(uint256(1)), "uint256-max-value() ** 0 ** 1"
        );

        // 1 exp anything is 1.
        checkHappy("_: uint256-power(0x01 0 0);", bytes32(uint256(1)), "1 ** 0 ** 0");
        checkHappy("_: uint256-power(0x01 0 0x01);", bytes32(uint256(1)), "1 ** 0 ** 1");
        checkHappy("_: uint256-power(0x01 0x01 0);", bytes32(uint256(1)), "1 ** 1 ** 0");
        checkHappy("_: uint256-power(0x01 0x01 0x01);", bytes32(uint256(1)), "1 ** 1 ** 1");
        checkHappy("_: uint256-power(0x01 0x02 0);", bytes32(uint256(1)), "1 ** 2 ** 0");
        checkHappy("_: uint256-power(0x01 0x02 0x01);", bytes32(uint256(1)), "1 ** 2 ** 1");
        checkHappy("_: uint256-power(0x01 0x02 0x02);", bytes32(uint256(1)), "1 ** 2 ** 2");
        checkHappy("_: uint256-power(0x01 0x03 0);", bytes32(uint256(1)), "1 ** 3 ** 0");

        // Anything exp 1 is itself.
        checkHappy("_: uint256-power(0 0x01 0x01);", 0, "0 ** 1 ** 1");
        checkHappy("_: uint256-power(0x01 0x01 0x01);", bytes32(uint256(1)), "1 ** 1 ** 1");
        checkHappy(
            "_: uint256-power(uint256-max-value() 0x01 0x01);", bytes32(type(uint256).max), "max-value() ** 1 ** 1"
        );

        // Anything exp 2 1 is itself squared.
        checkHappy("_: uint256-power(0 0x02 0x01);", 0, "0 ** 2 ** 0");
        checkHappy("_: uint256-power(0x01 0x02 0x01);", bytes32(uint256(1)), "1 ** 2 ** 0");
        checkHappy("_: uint256-power(0x02 0x02 0x01);", bytes32(uint256(4)), "2 ** 2 ** 0");
        checkHappy("_: uint256-power(0x03 0x02 0x01);", bytes32(uint256(9)), "3 ** 2 ** 0");

        // Anything exp 2 2 is itself squared squared.
        checkHappy("_: uint256-power(0 0x02 0x02);", 0, "0 ** 2 ** 2");
        checkHappy("_: uint256-power(0x01 0x02 0x02);", bytes32(uint256(1)), "1 ** 2 ** 2");
        checkHappy("_: uint256-power(0x02 0x02 0x02);", bytes32(uint256(16)), "2 ** 2 ** 2");
        checkHappy("_: uint256-power(0x03 0x02 0x02);", bytes32(uint256(81)), "3 ** 2 ** 2");

        // Anything exp 3 1 is itself cubed.
        checkHappy("_: uint256-power(0 0x03 0x01);", 0, "0 ** 3 ** 1");
        checkHappy("_: uint256-power(0x01 0x03 0x01);", bytes32(uint256(1)), "1 ** 3 ** 1");
        checkHappy("_: uint256-power(0x02 0x03 0x01);", bytes32(uint256(8)), "2 ** 3 ** 1");
        checkHappy("_: uint256-power(0x03 0x03 0x01);", bytes32(uint256(27)), "3 ** 3 ** 1");

        // Anything exp 3 2 is itself cubed squared.
        checkHappy("_: uint256-power(0 0x03 0x02);", 0, "0 ** 3 ** 2");
        checkHappy("_: uint256-power(0x01 0x03 0x02);", bytes32(uint256(1)), "1 ** 3 ** 2");
        checkHappy("_: uint256-power(0x02 0x03 0x02);", bytes32(uint256(64)), "2 ** 3 ** 2");
        checkHappy("_: uint256-power(0x03 0x03 0x02);", bytes32(uint256(729)), "3 ** 3 ** 2");

        // Anything exp 3 3 is itself cubed cubed.
        checkHappy("_: uint256-power(0 0x03 0x03);", 0, "0 ** 3 ** 3");
        checkHappy("_: uint256-power(0x01 0x03 0x03);", bytes32(uint256(1)), "1 ** 3 ** 3");
        checkHappy("_: uint256-power(0x02 0x03 0x03);", bytes32(uint256(512)), "2 ** 3 ** 3");
        checkHappy("_: uint256-power(0x03 0x03 0x03);", bytes32(uint256(19683)), "3 ** 3 ** 3");
    }

    /// Test the eval of `uint256-power` opcode parsed from a string. Tests three inputs.
    /// Tests the unhappy path where we overflow.
    function testOpUint256PowEval3InputsUnhappy() external {
        checkUnhappy("_: uint256-power(0x02 uint256-max-value() 0);", stdError.arithmeticError);
        checkUnhappy("_: uint256-power(0x03 uint256-max-value() 0);", stdError.arithmeticError);
        checkUnhappy("_: uint256-power(uint256-max-value() uint256-max-value() 0);", stdError.arithmeticError);
        checkUnhappy("_: uint256-power(0x02 uint256-max-value() 0x01);", stdError.arithmeticError);
        checkUnhappy("_: uint256-power(0x03 uint256-max-value() 0x01);", stdError.arithmeticError);
        checkUnhappy("_: uint256-power(uint256-max-value() uint256-max-value() 0x01);", stdError.arithmeticError);
        checkUnhappy("_: uint256-power(0x02 uint256-max-value() 0x02);", stdError.arithmeticError);
        checkUnhappy("_: uint256-power(0x03 uint256-max-value() 0x02);", stdError.arithmeticError);
        checkUnhappy("_: uint256-power(uint256-max-value() uint256-max-value() 0x02);", stdError.arithmeticError);
        checkUnhappy("_: uint256-power(0x02 uint256-max-value() 0x03);", stdError.arithmeticError);
        checkUnhappy("_: uint256-power(0x03 uint256-max-value() 0x03);", stdError.arithmeticError);
        checkUnhappy("_: uint256-power(uint256-max-value() uint256-max-value() 0x03);", stdError.arithmeticError);
    }

    /// Test the eval of `uint256-power` opcode parsed from a string.
    /// Tests that operands are disallowed.
    function testOpUint256PowEvalOperandDisallowed() external {
        checkDisallowedOperand("_: uint256-power<0>(0 0 0);");
        checkDisallowedOperand("_: uint256-power<1>(0 0 0);");
        checkDisallowedOperand("_: uint256-power<2>(0 0 0);");
        checkDisallowedOperand("_: uint256-power<3 1>(0 0 0);");
    }
}
