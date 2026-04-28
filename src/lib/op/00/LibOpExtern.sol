// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {
    NotAnExternContract,
    ExternIntegrityInputsMismatch,
    ExternIntegrityOutputsMismatch
} from "../../../error/ErrExtern.sol";
import {OutOfBoundsConstantRead} from "../../../error/ErrIntegrity.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {OperandV2} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {
    IInterpreterExternV4,
    ExternDispatchV2,
    EncodedExternDispatchV2,
    StackItem
} from "rain.interpreter.interface/interface/IInterpreterExternV4.sol";
import {LibExtern} from "../../extern/LibExtern.sol";
import {LibBytes32Array} from "rain.solmem/lib/LibBytes32Array.sol";
import {ERC165Checker} from "openzeppelin-contracts/contracts/utils/introspection/ERC165Checker.sol";
import {BadOutputsLength} from "../../../error/ErrExtern.sol";

/// @title LibOpExtern
/// @notice Implementation of calling an external contract.
library LibOpExtern {
    /// @notice `extern` integrity check. Validates the extern contract supports the expected interface and delegates to the extern's own integrity check.
    /// @param state The current integrity check state containing the constants.
    /// @param operand Encodes the extern dispatch index and input/output counts.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory state, OperandV2 operand) internal view returns (uint256, uint256) {
        uint256 encodedExternDispatchIndex = uint256(OperandV2.unwrap(operand) & bytes32(uint256(0xFFFF)));
        if (encodedExternDispatchIndex >= state.constants.length) {
            revert OutOfBoundsConstantRead(state.opIndex, state.constants.length, encodedExternDispatchIndex);
        }

        EncodedExternDispatchV2 encodedExternDispatch =
            EncodedExternDispatchV2.wrap(state.constants[encodedExternDispatchIndex]);
        (IInterpreterExternV4 extern, ExternDispatchV2 dispatch) = LibExtern.decodeExternCall(encodedExternDispatch);
        if (!ERC165Checker.supportsInterface(address(extern), type(IInterpreterExternV4).interfaceId)) {
            revert NotAnExternContract(address(extern));
        }
        uint256 expectedInputsLength = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;
        uint256 expectedOutputsLength = uint256(OperandV2.unwrap(operand) >> 0x14) & 0x0F;
        (uint256 actualInputs, uint256 actualOutputs) =
            extern.externIntegrity(dispatch, expectedInputsLength, expectedOutputsLength);
        if (actualInputs != expectedInputsLength) {
            revert ExternIntegrityInputsMismatch(expectedInputsLength, actualInputs);
        }
        if (actualOutputs != expectedOutputsLength) {
            revert ExternIntegrityOutputsMismatch(expectedOutputsLength, actualOutputs);
        }
        return (actualInputs, actualOutputs);
    }

    /// @notice `extern` opcode. Calls an external contract's `extern` function with stack inputs and pushes its outputs.
    /// @param state The interpreter state containing the constants array.
    /// @param operand Encodes the extern dispatch index and input/output counts.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory state, OperandV2 operand, Pointer stackTop) internal view returns (Pointer) {
        uint256 encodedExternDispatchIndex = uint256(OperandV2.unwrap(operand) & bytes32(uint256(0xFFFF)));
        uint256 inputsLength = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;
        uint256 outputsLength = uint256(OperandV2.unwrap(operand) >> 0x14) & 0x0F;

        bytes32 encodedExternDispatch = state.constants[encodedExternDispatchIndex];
        (IInterpreterExternV4 extern, ExternDispatchV2 dispatch) =
            LibExtern.decodeExternCall(EncodedExternDispatchV2.wrap(encodedExternDispatch));
        StackItem[] memory inputs;
        uint256 head;
        assembly ("memory-safe") {
            // Mutate the word before the current stack top to be the length of
            // the inputs array so we can treat it as an inputs array. This will
            // either mutate memory allocated to the stack that is not currently
            // in use, or the length of the stack array itself, which will need
            // to be repaired after the call. We store the original value of the
            // word before the stack top so we can restore it after the call,
            // just in case it is the latter scenario.
            inputs := sub(stackTop, 0x20)
            head := mload(inputs)
            mstore(inputs, inputsLength)
        }
        StackItem[] memory outputs = extern.extern(dispatch, inputs);
        if (outputsLength != outputs.length) {
            revert BadOutputsLength(outputsLength, outputs.length);
        }

        assembly ("memory-safe") {
            // Restore whatever was in memory before we built our inputs array.
            // Inputs is no longer safe to use after this point.
            mstore(inputs, head)
            stackTop := add(stackTop, mul(inputsLength, 0x20))
            // Copy outputs out.
            let sourceCursor := add(outputs, 0x20)
            let end := add(sourceCursor, mul(outputsLength, 0x20))
            // We loop this backwards so that the 0th output is _lowest_ on the
            // stack, which visually maps to:
            // `a b: extern<x 2>(a b);`
            // If the extern implementation is an identity function and has both
            // inputs and outputs as `[a, b]`.
            for {} lt(sourceCursor, end) { sourceCursor := add(sourceCursor, 0x20) } {
                stackTop := sub(stackTop, 0x20)
                mstore(stackTop, mload(sourceCursor))
            }
        }
        return stackTop;
    }

    /// @notice Reference implementation of `extern` for testing.
    /// @param state The interpreter state containing the constants array.
    /// @param operand Encodes the extern dispatch index and output count.
    /// @param inputs The input values from the stack.
    /// @return outputs The output values to push onto the stack.
    function referenceFn(InterpreterState memory state, OperandV2 operand, StackItem[] memory inputs)
        internal
        view
        returns (StackItem[] memory outputs)
    {
        uint256 encodedExternDispatchIndex = uint256(OperandV2.unwrap(operand) & bytes32(uint256(0xFFFF)));
        uint256 outputsLength = uint256(OperandV2.unwrap(operand) >> 0x14) & 0x0F;

        bytes32 encodedExternDispatch = state.constants[encodedExternDispatchIndex];
        (IInterpreterExternV4 extern, ExternDispatchV2 dispatch) =
            LibExtern.decodeExternCall(EncodedExternDispatchV2.wrap(encodedExternDispatch));
        outputs = extern.extern(dispatch, inputs);
        if (outputs.length != outputsLength) {
            revert BadOutputsLength(outputsLength, outputs.length);
        }
        // The stack is built backwards, so we need to reverse the outputs.
        bytes32[] memory outputsBytes32;
        assembly ("memory-safe") {
            outputsBytes32 := outputs
        }
        LibBytes32Array.reverse(outputsBytes32);
    }
}
