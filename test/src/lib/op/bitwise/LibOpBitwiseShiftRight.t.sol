// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {LibOpBitwiseShiftRight} from "../../../../../src/lib/op/bitwise/LibOpBitwiseShiftRight.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {UnsupportedBitwiseShiftAmount} from "../../../../../src/error/ErrBitwise.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {OperandOverflow} from "../../../../../src/error/ErrParse.sol";

contract LibOpBitwiseShiftRightTest is OpTest {
    function integrityExternal(IntegrityCheckState memory state, OperandV2 operand)
        external
        pure
        returns (uint256, uint256)
    {
        return LibOpBitwiseShiftRight.integrity(state, operand);
    }

    /// Directly test the integrity logic of LibOpBitwiseShiftRight. Tests the
    /// happy path where the integrity check does not error due to an unsupported
    /// shift amount.
    /// forge-config: default.fuzz.runs = 100
    function testOpShiftBitsRightIntegrityHappy(
        IntegrityCheckState memory state,
        uint8 inputs,
        uint8 outputs,
        uint8 shiftAmount
    ) external pure {
        vm.assume(shiftAmount != 0);
        inputs = uint8(bound(inputs, 1, 0x0F));
        outputs = uint8(bound(outputs, 1, 0x0F));
        OperandV2 operand = LibOperand.build(inputs, outputs, shiftAmount);
        (uint256 calcInputs, uint256 calcOutputs) = LibOpBitwiseShiftRight.integrity(state, operand);
        assertEq(calcInputs, 1);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the execution logic of LibOpBitwiseShiftRight. Tests that
    /// any shift amount that always results in an output of 0 will error as
    /// an unsupported shift amount.
    /// forge-config: default.fuzz.runs = 100
    function testOpShiftBitsRightIntegrityZero(IntegrityCheckState memory state, uint8 inputs, uint16 shiftAmount16)
        external
    {
        uint256 shiftAmount = bound(uint256(shiftAmount16), uint256(type(uint8).max) + 1, type(uint16).max);
        OperandV2 operand = OperandV2.wrap(bytes32(uint256(inputs) << 0x10 | shiftAmount));
        vm.expectRevert(abi.encodeWithSelector(UnsupportedBitwiseShiftAmount.selector, shiftAmount));
        (uint256 calcInputs, uint256 calcOutputs) = this.integrityExternal(state, operand);
        (calcInputs, calcOutputs);
    }

    /// Directly test the execution logic of LibOpBitwiseShiftRight. Tests that
    /// any shift amount that is a noop (0) will error as an unsupported shift
    /// amount.
    /// forge-config: default.fuzz.runs = 100
    function testOpShiftBitsRightIntegrityNoop(IntegrityCheckState memory state, uint8 inputs) external {
        OperandV2 operand = OperandV2.wrap(bytes32(uint256(inputs) << 0x10));
        vm.expectRevert(abi.encodeWithSelector(UnsupportedBitwiseShiftAmount.selector, 0));
        (uint256 calcInputs, uint256 calcOutputs) = this.integrityExternal(state, operand);
        (calcInputs, calcOutputs);
    }

    /// Directly test the runtime logic of LibOpBitwiseShiftRight. This tests that
    /// the opcode correctly shifts bits right.
    function testOpShiftBitsRightRun(StackItem x, uint8 shiftAmount) external view {
        vm.assume(shiftAmount != 0);
        InterpreterState memory state = opTestDefaultInterpreterState();
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = x;
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, shiftAmount);
        opReferenceCheck(
            state,
            operand,
            LibOpBitwiseShiftRight.referenceFn,
            LibOpBitwiseShiftRight.integrity,
            LibOpBitwiseShiftRight.run,
            inputs
        );
    }

    /// Test the eval of a shift bits right opcode parsed from a string.
    function testOpShiftBitsRightEval() external view {
        checkHappy("_: bitwise-shift-right<1>(0x00);", 0, "1, 0");
        checkHappy("_: bitwise-shift-right<2>(0x00);", 0, "2, 0");
        checkHappy("_: bitwise-shift-right<3>(0x00);", 0, "3, 0");
        checkHappy("_: bitwise-shift-right<255>(0x00);", 0, "255, 0");

        checkHappy("_: bitwise-shift-right<1>(0x01);", 0, "1, 1");
        checkHappy("_: bitwise-shift-right<2>(0x01);", 0, "2, 1");
        checkHappy("_: bitwise-shift-right<3>(0x01);", 0, "3, 1");
        checkHappy("_: bitwise-shift-right<255>(0x01);", 0, "255, 1");

        checkHappy("_: bitwise-shift-right<1>(0x02);", bytes32(uint256(1)), "1, 2");
        checkHappy("_: bitwise-shift-right<2>(0x02);", 0, "2, 2");
        checkHappy("_: bitwise-shift-right<3>(0x02);", 0, "3, 2");
        checkHappy("_: bitwise-shift-right<255>(0x02);", 0, "255, 2");

        checkHappy("_: bitwise-shift-right<1>(0x03);", bytes32(uint256(1)), "1, 3");
        checkHappy("_: bitwise-shift-right<2>(0x03);", 0, "2, 3");
        checkHappy("_: bitwise-shift-right<3>(0x03);", 0, "3, 3");
        checkHappy("_: bitwise-shift-right<255>(0x03);", 0, "255, 3");

        checkHappy("_: bitwise-shift-right<1>(0x04);", bytes32(uint256(2)), "1, 4");
        checkHappy("_: bitwise-shift-right<2>(0x04);", bytes32(uint256(1)), "2, 4");
        checkHappy("_: bitwise-shift-right<3>(0x04);", 0, "3, 4");
        checkHappy("_: bitwise-shift-right<255>(0x04);", 0, "255, 4");

        checkHappy("_: bitwise-shift-right<1>(uint256-max-value());", bytes32(type(uint256).max >> 1), "1, max");
        checkHappy("_: bitwise-shift-right<2>(uint256-max-value());", bytes32(type(uint256).max >> 2), "2, max");
        checkHappy("_: bitwise-shift-right<3>(uint256-max-value());", bytes32(type(uint256).max >> 3), "3, max");
        checkHappy("_: bitwise-shift-right<255>(uint256-max-value());", bytes32(uint256(1)), "255, max");
    }

    /// Test that a bitwise shift with bad inputs fails integrity.
    function testOpShiftBitsRightZeroInputs() external {
        checkBadInputs("_: bitwise-shift-right<1>();", 0, 1, 0);
    }

    function testOpShiftBitsRightTwoInputs() external {
        checkBadInputs("_: bitwise-shift-right<1>(0 0);", 2, 1, 2);
    }

    function testOpShiftBitsRightZeroOutputs() external {
        checkBadOutputs(": bitwise-shift-right<1>(0);", 1, 1, 0);
    }

    function testOpShiftBitsRightTwoOutputs() external {
        checkBadOutputs("_ _: bitwise-shift-right<1>(0);", 1, 1, 2);
    }

    /// Test that a bitwise shift with bad shift amount fails integrity.
    function testOpShiftBitsRightIntegrityFailBadShiftAmount() external {
        checkUnhappyParse2(
            "_: bitwise-shift-right<0>(0);", abi.encodeWithSelector(UnsupportedBitwiseShiftAmount.selector, 0)
        );
        checkUnhappyParse2(
            "_: bitwise-shift-right<256>(0);", abi.encodeWithSelector(UnsupportedBitwiseShiftAmount.selector, 256)
        );
        // Something even bigger than 256, but without overflowing the uint16
        // for the operand itself.
        checkUnhappyParse2(
            "_: bitwise-shift-right<65535>(0);", abi.encodeWithSelector(UnsupportedBitwiseShiftAmount.selector, 65535)
        );
        // Lets go ahead and overflow the operand.
        checkUnhappyParse("_: bitwise-shift-right<65536>(0);", abi.encodeWithSelector(OperandOverflow.selector));
    }
}
