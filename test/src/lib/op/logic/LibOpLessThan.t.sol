// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpLessThan} from "../../../../../src/lib/op/logic/LibOpLessThan.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {IntegrityCheckState, BadOpInputsLength} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";

contract LibOpLessThanTest is OpTest {
    /// Directly test the integrity logic of LibOpLessThan. No matter the
    /// operand inputs, the calc inputs must be 2, and the calc outputs must be
    /// 1.
    function testOpLessThanIntegrityHappy(
        IntegrityCheckState memory state,
        uint8 inputs,
        uint8 outputs,
        uint16 operandData
    ) external pure {
        inputs = uint8(bound(inputs, 0, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpLessThan.integrity(state, LibOperand.build(inputs, outputs, operandData));

        // The inputs from the operand are ignored. The op is always 2 inputs.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpLessThan.
    function testOpLessThanRun(StackItem input1, StackItem input2) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = input1;
        inputs[1] = input2;
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(state, operand, LibOpLessThan.referenceFn, LibOpLessThan.integrity, LibOpLessThan.run, inputs);
    }

    /// Test the eval of less than opcode parsed from a string. Tests 2 inputs.
    /// Both inputs are 0.
    function testOpLessThanEval2ZeroInputs() external view {
        checkHappy("_: less-than(0 0);", 0, "");
    }

    /// Test the eval of less than opcode parsed from a string. Tests 2 inputs.
    /// The first input is 0, the second input is 1.
    function testOpLessThanEval2InputsFirstZeroSecondOne() external view {
        checkHappy("_: less-than(0 1);", bytes32(uint256(1)), "");
    }

    /// Test the eval of less than opcode parsed from a string. Tests 2 inputs.
    /// The first input is 1, the second input is 0.
    function testOpLessThanEval2InputsFirstOneSecondZero() external view {
        checkHappy("_: less-than(1 0);", bytes32(uint256(0)), "");
    }

    /// Test the eval of less than opcode parsed from a string. Tests 2 inputs.
    /// Both inputs are 1.
    function testOpLessThanEval2InputsBothOne() external view {
        checkHappy("_: less-than(1 1);", bytes32(uint256(0)), "");
    }

    // Test 1.1 lt 1.2, which should return 1.
    function testOpLessThan1_1Lt1_2() external view {
        checkHappy("_: less-than(1.1 1.2);", bytes32(uint256(1)), "");
    }

    /// Test 1.0 lt 1 which should return 0.
    function testOpLessThan1_0Lt1() external view {
        checkHappy("_: less-than(1.0 1);", bytes32(uint256(0)), "");
    }

    // Test -1.1 lt -1.2, which should return 0.
    function testOpLessThanMinus1_1LtMinus1_2() external view {
        checkHappy("_: less-than(-1.1 -1.2);", bytes32(uint256(0)), "");
    }

    /// Test -1 lt 0, which should return 1.
    function testOpLessThanMinus1Lt0() external view {
        checkHappy("_: less-than(-1 0);", bytes32(uint256(1)), "");
    }

    /// Test that a less than to without inputs fails integrity check.
    function testOpLessThanToEvalFail0Inputs() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 0, 2, 0));
        bytes memory bytecode = I_DEPLOYER.parse2("_: less-than();");
        (bytecode);
    }

    /// Test that a less than to with 1 input fails integrity check.
    function testOpLessThanToEvalFail1Input() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 1, 2, 1));
        bytes memory bytecode = I_DEPLOYER.parse2("_: less-than(0x00);");
        (bytecode);
    }

    /// Test that a less than to with 3 inputs fails integrity check.
    function testOpLessThanToEvalFail3Inputs() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 3, 2, 3));
        bytes memory bytecode = I_DEPLOYER.parse2("_: less-than(0x00 0x00 0x00);");
        (bytecode);
    }

    function testOpLessThanZeroOutputs() external {
        checkBadOutputs(": less-than(0 0);", 2, 1, 0);
    }

    function testOpLessThanTwoOutputs() external {
        checkBadOutputs("_ _: less-than(30 0);", 2, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpLessThanEvalOperandDisallowed() external {
        checkUnhappyParse("_: less-than<0>(1 2);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
