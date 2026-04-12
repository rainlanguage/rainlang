// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {OutOfBoundsStackRead} from "../../../error/ErrIntegrity.sol";

/// @title LibOpStack
/// @notice Implementation of copying a stack item from the stack to the stack.
/// Integrated deeply into LibParse, which requires this opcode or a variant
/// to be present at a known opcode index.
library LibOpStack {
    /// @notice `stack` integrity check. Validates the read index is within bounds.
    /// @param state The current integrity check state containing the stack index.
    /// @param operand Encodes the stack read index in the low 16 bits.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory state, OperandV2 operand) internal pure returns (uint256, uint256) {
        uint256 readIndex = uint256(OperandV2.unwrap(operand) & bytes32(uint256(0xFFFF)));
        // Operand is the index so ensure it doesn't exceed the stack index.
        if (readIndex >= state.stackIndex) {
            revert OutOfBoundsStackRead(state.opIndex, state.stackIndex, readIndex);
        }

        // Move the read highwater if needed.
        if (readIndex > state.readHighwater) {
            state.readHighwater = readIndex;
        }

        return (0, 1);
    }

    /// @notice `stack` opcode. Copies a value from a previous stack position to the top.
    /// @param state The interpreter state containing the stack bottoms.
    /// @param operand Encodes the stack read index in the low 16 bits.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory state, OperandV2 operand, Pointer stackTop) internal pure returns (Pointer) {
        uint256 sourceIndex = state.sourceIndex;
        Pointer[] memory stackBottoms = state.stackBottoms;
        assembly ("memory-safe") {
            let stackBottom := mload(add(stackBottoms, mul(0x20, add(sourceIndex, 1))))
            let stackValue := mload(sub(stackBottom, mul(0x20, add(and(operand, 0xFFFF), 1))))
            stackTop := sub(stackTop, 0x20)
            mstore(stackTop, stackValue)
        }
        return stackTop;
    }

    /// @notice Reference implementation of `stack` for testing. Uses Solidity for
    /// bounds-checked array access and operand extraction, with only the
    /// final pointer dereference in assembly.
    /// @param state The interpreter state containing the stack bottoms.
    /// @param operand Encodes the stack read index in the low 16 bits.
    /// @return outputs The output values to push onto the stack.
    function referenceFn(InterpreterState memory state, OperandV2 operand, StackItem[] memory)
        internal
        pure
        returns (StackItem[] memory outputs)
    {
        uint256 readIndex = uint256(OperandV2.unwrap(operand) & bytes32(uint256(0xFFFF)));
        // Solidity bounds-checked array access, unlike run() which relies on
        // integrity.
        uint256 stackBottom = Pointer.unwrap(state.stackBottoms[state.sourceIndex]);
        uint256 readPointer = stackBottom - (readIndex + 1) * 0x20;
        outputs = new StackItem[](1);
        assembly ("memory-safe") {
            mstore(add(outputs, 0x20), mload(readPointer))
        }
    }
}
