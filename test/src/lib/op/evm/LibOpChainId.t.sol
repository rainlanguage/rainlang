// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";

import {LibInterpreterState, InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {IntegrityCheckState, BadOpInputsLength} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {LibOpChainId} from "../../../../../src/lib/op/evm/LibOpChainId.sol";

import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";

/// @title LibOpChainIdTest
/// @notice Test the runtime and integrity time logic of LibOpChainId.
contract LibOpChainIdTest is OpTest {
    using LibInterpreterState for InterpreterState;

    /// Directly test the integrity logic of LibOpChainId.
    function testOpChainIDIntegrity(IntegrityCheckState memory state, uint8 inputs, uint8 outputs, uint16 operandData)
        external
        pure
    {
        inputs = uint8(bound(inputs, 0, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpChainId.integrity(state, LibOperand.build(inputs, outputs, operandData));

        assertEq(calcInputs, 0);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpChainId. This tests that the
    /// opcode correctly pushes the chain ID onto the stack.
    function testOpChainIdRun(uint64 chainId, uint16 operandData) external {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.chainId(chainId);
        StackItem[] memory inputs = new StackItem[](0);
        OperandV2 operand = LibOperand.build(0, 1, operandData);
        opReferenceCheck(state, operand, LibOpChainId.referenceFn, LibOpChainId.integrity, LibOpChainId.run, inputs);
    }

    /// Test the eval of a chain ID opcode parsed from a string.
    function testOpChainIDEval(uint64 chainId) public {
        vm.chainId(chainId);
        checkHappy("_: chain-id();", bytes32(uint256(chainId)), "");
    }

    /// Test that a chain ID with inputs fails integrity check.
    function testOpChainIdEvalFail() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 1, 0, 1));
        bytes memory bytecode = I_DEPLOYER.parse2("_: chain-id(0x00);");
        (bytecode);
    }

    function testOpChainIdZeroOutputs() external {
        checkBadOutputs(": chain-id();", 0, 1, 0);
    }

    function testOpChainIdTwoOutputs() external {
        checkBadOutputs("_ _: chain-id();", 0, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpChainIdEvalOperandDisallowed() external {
        checkUnhappyParse("_: chain-id<0>();", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
