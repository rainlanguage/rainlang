// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {LibOpBitwiseShiftLeft} from "../../../../../src/lib/op/bitwise/LibOpBitwiseShiftLeft.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {UnsupportedBitwiseShiftAmount} from "../../../../../src/error/ErrBitwise.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {OperandOverflow} from "../../../../../src/error/ErrParse.sol";

contract LibOpBitwiseShiftLeftTest is OpTest {
    function integrityExternal(IntegrityCheckState memory state, OperandV2 operand)
        external
        pure
        returns (uint256, uint256)
    {
        return LibOpBitwiseShiftLeft.integrity(state, operand);
    }

    /// Directly test the integrity logic of LibOpBitwiseShiftLeft. Tests the
    /// happy path where the integrity check does not error due to an unsupported
    /// shift amount.
    function testOpShiftBitsLeftIntegrityHappy(
        IntegrityCheckState memory state,
        uint8 inputs,
        uint8 outputs,
        uint8 shiftAmount
    ) external pure {
        vm.assume(shiftAmount != 0);
        inputs = uint8(bound(inputs, 1, 0x0F));
        outputs = uint8(bound(outputs, 1, 0x0F));
        OperandV2 operand = LibOperand.build(inputs, outputs, shiftAmount);
        (uint256 calcInputs, uint256 calcOutputs) = LibOpBitwiseShiftLeft.integrity(state, operand);
        assertEq(calcInputs, 1);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the execution logic of LibOpBitwiseShiftLeft. Tests that
    /// any shift amount that always results in an output of 0 will error as
    /// an unsupported shift amount.
    function testOpShiftBitsLeftIntegrityZero(IntegrityCheckState memory state, uint8 inputs, uint16 shiftAmount16)
        external
    {
        inputs = uint8(bound(inputs, 0, 0x0F));
        uint256 shiftAmount = bound(uint256(shiftAmount16), uint256(type(uint8).max) + 1, type(uint16).max);
        // Bounds ensure the typecast is safe.
        //forge-lint: disable-next-line(unsafe-typecast)
        OperandV2 operand = LibOperand.build(inputs, 1, uint16(shiftAmount));
        vm.expectRevert(abi.encodeWithSelector(UnsupportedBitwiseShiftAmount.selector, shiftAmount));
        (uint256 calcInputs, uint256 calcOutputs) = this.integrityExternal(state, operand);
        (calcInputs, calcOutputs);
    }

    /// Directly test the execution logic of LibOpBitwiseShiftLeft. Tests that
    /// any shift amount that is a noop (0) will error as an unsupported shift
    /// amount.
    function testOpShiftBitsLeftIntegrityNoop(IntegrityCheckState memory state, uint8 inputs) external {
        OperandV2 operand = OperandV2.wrap(bytes32(uint256(inputs) << 0x10));
        vm.expectRevert(abi.encodeWithSelector(UnsupportedBitwiseShiftAmount.selector, 0));
        (uint256 calcInputs, uint256 calcOutputs) = this.integrityExternal(state, operand);
        (calcInputs, calcOutputs);
    }

    /// Directly test the runtime logic of LibOpBitwiseShiftLeft. This tests that
    /// the opcode correctly shifts bits left.
    function testOpShiftBitsLeftRun(StackItem x, uint8 shiftAmount) external view {
        vm.assume(shiftAmount != 0);
        InterpreterState memory state = opTestDefaultInterpreterState();
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = x;
        OperandV2 operand = LibOperand.build(1, 1, shiftAmount);
        opReferenceCheck(
            state,
            operand,
            LibOpBitwiseShiftLeft.referenceFn,
            LibOpBitwiseShiftLeft.integrity,
            LibOpBitwiseShiftLeft.run,
            inputs
        );
    }

    /// Test the eval of a shift bits left opcode parsed from a string.
    function testOpShiftBitsLeftEval() external view {
        checkHappy("_: bitwise-shift-left<1>(0x00);", 0, "1, 0");
        checkHappy("_: bitwise-shift-left<2>(0x00);", 0, "2, 0");
        checkHappy("_: bitwise-shift-left<3>(0x00);", 0, "3, 0");
        checkHappy("_: bitwise-shift-left<255>(0x00);", 0, "255, 0");

        checkHappy("_: bitwise-shift-left<1>(0x01);", bytes32(uint256(1 << 1)), "1, 1");
        checkHappy("_: bitwise-shift-left<2>(0x01);", bytes32(uint256(1 << 2)), "2, 1");
        checkHappy("_: bitwise-shift-left<3>(0x01);", bytes32(uint256(1 << 3)), "3, 1");
        checkHappy("_: bitwise-shift-left<255>(0x01);", bytes32(uint256(1 << 255)), "255, 1");

        checkHappy("_: bitwise-shift-left<1>(0x02);", bytes32(uint256(2 << 1)), "1, 2");
        checkHappy("_: bitwise-shift-left<2>(0x02);", bytes32(uint256(2 << 2)), "2, 2");
        checkHappy("_: bitwise-shift-left<3>(0x02);", bytes32(uint256(2 << 3)), "3, 2");
        // 2 gets shifted out of the 256 bit word, so this is 0.
        checkHappy("_: bitwise-shift-left<255>(0x02);", 0, "255, 2");

        checkHappy("_: bitwise-shift-left<1>(0x03);", bytes32(uint256(3 << 1)), "1, 3");
        checkHappy("_: bitwise-shift-left<2>(0x03);", bytes32(uint256(3 << 2)), "2, 3");
        checkHappy("_: bitwise-shift-left<3>(0x03);", bytes32(uint256(3 << 3)), "3, 3");
        // The high bit of 3 gets shifted out of the 256 bit word, so this is the
        // same as shifting 1.
        checkHappy("_: bitwise-shift-left<255>(0x03);", bytes32(uint256(1 << 255)), "255, 3");

        checkHappy("_: bitwise-shift-left<1>(uint256-max-value());", bytes32(type(uint256).max << 1), "1, max");
        checkHappy("_: bitwise-shift-left<2>(uint256-max-value());", bytes32(type(uint256).max << 2), "2, max");
        checkHappy("_: bitwise-shift-left<3>(uint256-max-value());", bytes32(type(uint256).max << 3), "3, max");
        // The high bit of max gets shifted out of the 256 bit word, so this is the
        // same as shifting 1.
        checkHappy("_: bitwise-shift-left<255>(uint256-max-value());", bytes32(uint256(1 << 255)), "255, max");
    }

    /// Test that a bitwise shift with bad inputs fails integrity.
    function testOpShiftBitsLeftIntegrityFailZeroInputs() external {
        checkBadInputs("_: bitwise-shift-left<1>();", 0, 1, 0);
    }

    function testOpShiftBitsLeftIntegrityFailTwoInputs() external {
        checkBadInputs("_: bitwise-shift-left<1>(0 0);", 2, 1, 2);
    }

    function testOpShiftBitsLeftIntegrityFailZeroOutputs() external {
        checkBadOutputs(": bitwise-shift-left<1>(0);", 1, 1, 0);
    }

    function testOpShiftBitsLeftIntegrityFailTwoOutputs() external {
        checkBadOutputs("_ _: bitwise-shift-left<1>(0);", 1, 1, 2);
    }

    /// Test that a bitwise shift with bad shift amount fails integrity.
    function testOpShiftBitsLeftIntegrityFailBadShiftAmount() external {
        checkUnhappyParse2(
            "_: bitwise-shift-left<0>(0);", abi.encodeWithSelector(UnsupportedBitwiseShiftAmount.selector, 0)
        );
        checkUnhappyParse2(
            "_: bitwise-shift-left<256>(0);", abi.encodeWithSelector(UnsupportedBitwiseShiftAmount.selector, 256)
        );
        // Something even bigger than 256, but without overflowing the uint16
        // for the operand itself.
        checkUnhappyParse2(
            "_: bitwise-shift-left<65535>(0);", abi.encodeWithSelector(UnsupportedBitwiseShiftAmount.selector, 65535)
        );
        // Lets go ahead and overflow the operand.
        checkUnhappyParse("_: bitwise-shift-left<65536>(0);", abi.encodeWithSelector(OperandOverflow.selector));
    }
}
