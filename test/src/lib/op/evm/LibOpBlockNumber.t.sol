// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";

import {LibPointer, Pointer} from "rain.solmem/lib/LibPointer.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibStackPointer} from "rain.solmem/lib/LibStackPointer.sol";
import {LibInterpreterState, InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {LibOpBlockNumber} from "../../../../../src/lib/op/evm/LibOpBlockNumber.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";

/// @title LibOpBlockNumberTest
/// @notice Test the runtime and integrity time logic of LibOpBlockNumber.
contract LibOpBlockNumberTest is OpTest {
    using LibPointer for Pointer;
    using LibStackPointer for Pointer;
    using LibInterpreterState for InterpreterState;

    /// Directly test the integrity logic of LibOpBlockNumber.
    function testOpBlockNumberIntegrity(
        IntegrityCheckState memory state,
        uint8 inputs,
        uint8 outputs,
        uint16 operandData
    ) external pure {
        inputs = uint8(bound(inputs, 0, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpBlockNumber.integrity(state, LibOperand.build(inputs, outputs, operandData));

        assertEq(calcInputs, 0);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpBlockNumber. This tests that the
    /// opcode correctly pushes the block number onto the stack.
    function testOpBlockNumberRun(uint256 blockNumber, uint16 operandData) external {
        blockNumber = bound(blockNumber, 0, uint256(type(uint64).max));
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.roll(blockNumber);
        StackItem[] memory inputs = new StackItem[](0);
        OperandV2 operand = LibOperand.build(0, 1, operandData);
        opReferenceCheck(
            state, operand, LibOpBlockNumber.referenceFn, LibOpBlockNumber.integrity, LibOpBlockNumber.run, inputs
        );
    }

    /// Test the eval of a block number opcode parsed from a string.
    function testOpBlockNumberEval(uint256 blockNumber) public {
        blockNumber = bound(blockNumber, 0, uint256(int256(type(int128).max)));
        vm.roll(blockNumber);
        checkHappy("_: block-number();", bytes32(uint256(blockNumber)), "");
    }

    function testOpBlockNumberEvalOneInput() external {
        checkBadInputs("_: block-number(0x00);", 1, 0, 1);
    }

    function testOpBlockNumberEvalZeroOutputs() external {
        checkBadOutputs(": block-number();", 0, 1, 0);
    }

    function testOpBlockNumberEvalTwoOutputs() external {
        checkBadOutputs("_ _: block-number();", 0, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpBlockNumberEvalOperandDisallowed() external {
        checkUnhappyParse("_: block-number<0>();", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
