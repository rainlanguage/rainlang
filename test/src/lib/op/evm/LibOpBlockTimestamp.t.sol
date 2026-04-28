// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {Pointer, LibPointer} from "rain.solmem/lib/LibPointer.sol";
import {LibStackPointer} from "rain.solmem/lib/LibStackPointer.sol";
import {LibInterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {OperandV2, SourceIndexV2, EvalV4, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {IntegrityCheckState, BadOpInputsLength} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {FullyQualifiedNamespace} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV4.sol";
import {LibContext} from "rain.interpreter.interface/lib/caller/LibContext.sol";

import {LibOpBlockTimestamp} from "../../../../../src/lib/op/evm/LibOpBlockTimestamp.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";

/// @title LibOpBlockTimestampTest
/// @notice Test the runtime and integrity time logic of LibOpBlockTimestamp.
contract LibOpBlockTimestampTest is OpTest {
    using LibPointer for Pointer;
    using LibStackPointer for Pointer;
    using LibInterpreterState for InterpreterState;

    function timestampWords() internal pure returns (string[] memory) {
        string[] memory words = new string[](2);
        words[0] = "block-timestamp";
        words[1] = "now";
        return words;
    }

    /// Directly test the integrity logic of LibOpBlockTimestamp.
    function testOpTimestampIntegrity(IntegrityCheckState memory state, uint8 inputs, uint8 outputs, uint16 operandData)
        external
        pure
    {
        inputs = uint8(bound(inputs, 0, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpBlockTimestamp.integrity(state, LibOperand.build(inputs, outputs, operandData));

        assertEq(calcInputs, 0);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpBlockTimestamp. This tests that the
    /// opcode correctly pushes the timestamp onto the stack.
    function testOpTimestampRun(uint256 blockTimestamp) external {
        blockTimestamp = bound(blockTimestamp, 0, uint128(type(int128).max));
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.warp(blockTimestamp);
        StackItem[] memory inputs = new StackItem[](0);
        OperandV2 operand = LibOperand.build(0, 1, 0);
        opReferenceCheck(
            state,
            operand,
            LibOpBlockTimestamp.referenceFn,
            LibOpBlockTimestamp.integrity,
            LibOpBlockTimestamp.run,
            inputs
        );
    }

    /// Test the eval of a timestamp opcode parsed from a string.
    function testOpTimestampEval(uint256 blockTimestamp) external {
        string[] memory words = timestampWords();

        for (uint256 i; i < words.length; ++i) {
            blockTimestamp = bound(blockTimestamp, 0, uint256(type(uint64).max));
            vm.warp(blockTimestamp);
            bytes memory bytecode = I_DEPLOYER.parse2(bytes(string.concat("_: ", words[i], "();")));
            (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
                EvalV4({
                    store: I_STORE,
                    namespace: FullyQualifiedNamespace.wrap(0),
                    bytecode: bytecode,
                    sourceIndex: SourceIndexV2.wrap(0),
                    context: LibContext.build(new bytes32[][](0), new SignedContextV1[](0)),
                    inputs: new StackItem[](0),
                    stateOverlay: new bytes32[](0)
                })
            );
            assertEq(stack.length, 1);
            assertEq(StackItem.unwrap(stack[0]), bytes32(blockTimestamp));
            assertEq(kvs.length, 0);
        }
    }

    /// Test that a block timestamp with inputs fails integrity check.
    function testOpBlockTimestampEvalFail() external {
        string[] memory words = timestampWords();

        for (uint256 i; i < words.length; ++i) {
            vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 1, 0, 1));
            bytes memory bytecode = I_DEPLOYER.parse2(bytes(string.concat("_: ", words[i], "(0x00);")));
            (bytecode);
        }
    }

    function testOpBlockTimestampZeroOutputs() external {
        string[] memory words = timestampWords();

        for (uint256 i; i < words.length; ++i) {
            checkBadOutputs(bytes(string.concat(": ", words[i], "();")), 0, 1, 0);
        }
    }

    function testOpBlockTimestampTwoOutputs() external {
        string[] memory words = timestampWords();

        for (uint256 i; i < words.length; ++i) {
            checkBadOutputs(bytes(string.concat("_ _: ", words[i], "();")), 0, 1, 2);
        }
    }

    /// Test that operand is disallowed for block-timestamp.
    function testOpBlockTimestampEvalOperandDisallowed() external {
        checkUnhappyParse("_: block-timestamp<0>();", abi.encodeWithSelector(UnexpectedOperand.selector));
    }

    /// Test that operand is disallowed for now.
    function testOpNowEvalOperandDisallowed() external {
        checkUnhappyParse("_: now<0>();", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
