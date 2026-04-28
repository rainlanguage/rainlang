// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpEqualTo} from "../../../../../src/lib/op/logic/LibOpEqualTo.sol";
import {IntegrityCheckState, BadOpInputsLength} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";

contract LibOpEqualToTest is OpTest {
    /// Directly test the integrity logic of LibOpEqualTo. No matter the
    /// operand inputs, the calc inputs must be 2, and the calc outputs must be
    /// 1.
    function testOpEqualToIntegrityHappy(
        IntegrityCheckState memory state,
        uint8 inputs,
        uint8 outputs,
        uint16 operandData
    ) external pure {
        inputs = uint8(bound(inputs, 0, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpEqualTo.integrity(state, LibOperand.build(inputs, outputs, operandData));

        // The inputs from the operand are ignored. The op is always 2 inputs.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpEqualTo.
    function testOpEqualToRun(StackItem input1, StackItem input2) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = input1;
        inputs[1] = input2;
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(state, operand, LibOpEqualTo.referenceFn, LibOpEqualTo.integrity, LibOpEqualTo.run, inputs);
    }

    /// Test the eval of greater than opcode parsed from a string. Tests 2
    /// inputs. Both inputs are 0.
    function testOpEqualToEval2ZeroInputs() external view {
        checkHappy("_: equal-to(0 0);", bytes32(uint256(1)), "");
    }

    /// Test the eval of greater than opcode parsed from a string. Tests 2
    /// inputs. The first input is 0, the second input is 1.
    function testOpEqualToEval2InputsFirstZeroSecondOne() external view {
        checkHappy("_: equal-to(0 1);", 0, "");
    }

    /// Test the eval of greater than opcode parsed from a string. Tests 2
    /// inputs. The first input is 1, the second input is 0.
    function testOpEqualToEval2InputsFirstOneSecondZero() external view {
        checkHappy("_: equal-to(1 0);", 0, "");
    }

    /// Test the eval of greater than opcode parsed from a string. Tests 2
    /// inputs. Both inputs are 1.
    function testOpEqualToEval2InputsBothOne() external view {
        checkHappy("_: equal-to(1 1);", bytes32(uint256(1)), "");
    }

    /// A few examples of different exponents with the same numerical value.
    function testOpEqualToEval2Inputs() external view {
        checkHappy("_: equal-to(1 1e0);", bytes32(uint256(1)), "");
        checkHappy("_: equal-to(10 10e0);", bytes32(uint256(1)), "");
        checkHappy("_: equal-to(1e1 10);", bytes32(uint256(1)), "");
        checkHappy("_: equal-to(0.2 2e-1);", bytes32(uint256(1)), "");
        checkHappy("_: equal-to(100e5 10e6);", bytes32(uint256(1)), "");
        checkHappy("_: equal-to(0x01 1);", bytes32(uint256(1)), "");
        checkHappy("_: equal-to(0x01 10e-1);", bytes32(uint256(1)), "");
    }

    /// Test that an equal to without inputs fails integrity check.
    function testOpEqualToEvalFail0Inputs() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 0, 2, 0));
        bytes memory bytecode = I_DEPLOYER.parse2("_: equal-to();");
        (bytecode);
    }

    /// Test that an equal to with 1 input fails integrity check.
    function testOpEqualToEvalFail1Input() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 1, 2, 1));
        bytes memory bytecode = I_DEPLOYER.parse2("_: equal-to(0x00);");
        (bytecode);
    }

    /// Test that an equal to with 3 inputs fails integrity check.
    function testOpEqualToEvalFail3Inputs() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 3, 2, 3));
        bytes memory bytecode = I_DEPLOYER.parse2("_: equal-to(0x00 0x00 0x00);");
        (bytecode);
    }

    function testOpEqualToZeroOutputs() external {
        checkBadOutputs(": equal-to(0 0);", 2, 1, 0);
    }

    function testOpEqualToTwoOutputs() external {
        checkBadOutputs("_ _: equal-to(0 0);", 2, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpEqualToEvalOperandDisallowed() external {
        checkUnhappyParse("_: equal-to<0>(1 2);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
