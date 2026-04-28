// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {LibInterpreterState, InterpreterState} from "../../../../src/lib/state/LibInterpreterState.sol";
import {LibAllStandardOps} from "../../../../src/lib/op/LibAllStandardOps.sol";
import {LibEval} from "../../../../src/lib/eval/LibEval.sol";
import {MemoryKV} from "rain.lib.memkv/lib/LibMemoryKV.sol";
import {
    IInterpreterStoreV3,
    FullyQualifiedNamespace
} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InputsLengthMismatch} from "../../../../src/error/ErrEval.sol";

/// @title LibEvalInputsLengthMismatchTest
/// @notice Direct library-level tests for the InputsLengthMismatch revert in
/// LibEval.eval4, using hand-built bytecode and InterpreterState.
contract LibEvalInputsLengthMismatchTest is Test {
    /// External wrapper so vm.expectRevert works with the library call.
    function externalEval4(InterpreterState memory state, StackItem[] memory inputs, uint256 maxOutputs)
        external
        view
        returns (StackItem[] memory, bytes32[] memory)
    {
        return LibEval.eval4(state, inputs, maxOutputs);
    }

    /// Build an InterpreterState with a single source that expects
    /// `sourceInputs` inputs and has 0 ops / 0 outputs.
    function buildState(uint8 sourceInputs) internal pure returns (InterpreterState memory) {
        bytes memory fs = LibAllStandardOps.opcodeFunctionPointers();

        // Bytecode: 1 source, 0 offset, 0 ops, sourceInputs stack allocation,
        // sourceInputs inputs, 0 outputs.
        bytes memory bytecode = abi.encodePacked(uint8(1), uint16(0), uint8(0), sourceInputs, sourceInputs, uint8(0));

        StackItem[][] memory stacks = new StackItem[][](1);
        stacks[0] = new StackItem[](sourceInputs);

        return InterpreterState(
            LibInterpreterState.stackBottoms(stacks),
            new bytes32[](0),
            0,
            MemoryKV.wrap(0),
            FullyQualifiedNamespace.wrap(0),
            IInterpreterStoreV3(address(0)),
            new bytes32[][](0),
            bytecode,
            fs
        );
    }

    /// Passing fewer inputs than the source expects must revert.
    function testEval4InputsTooFew() external {
        InterpreterState memory state = buildState(2);
        StackItem[] memory inputs = new StackItem[](1);

        vm.expectRevert(abi.encodeWithSelector(InputsLengthMismatch.selector, 2, 1));
        this.externalEval4(state, inputs, type(uint256).max);
    }

    /// Passing more inputs than the source expects must revert.
    function testEval4InputsTooMany() external {
        InterpreterState memory state = buildState(1);
        StackItem[] memory inputs = new StackItem[](2);

        vm.expectRevert(abi.encodeWithSelector(InputsLengthMismatch.selector, 1, 2));
        this.externalEval4(state, inputs, type(uint256).max);
    }

    /// Passing zero inputs when the source expects some must revert.
    function testEval4InputsZeroWhenExpected() external {
        InterpreterState memory state = buildState(3);
        StackItem[] memory inputs = new StackItem[](0);

        vm.expectRevert(abi.encodeWithSelector(InputsLengthMismatch.selector, 3, 0));
        this.externalEval4(state, inputs, type(uint256).max);
    }

    /// Passing the correct number of inputs must not revert.
    function testEval4InputsMatch() external view {
        InterpreterState memory state = buildState(2);
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(1)));
        inputs[1] = StackItem.wrap(bytes32(uint256(2)));

        this.externalEval4(state, inputs, type(uint256).max);
    }
}
