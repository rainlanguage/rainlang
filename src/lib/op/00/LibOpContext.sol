// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Pointer} from "rain-solmem-0.1.3/src/lib/LibPointer.sol";
import {OperandV2, StackItem} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";

/// @title LibOpContext
/// @notice Implementation of reading from the context matrix onto the stack.
///
/// @dev The interpreter exposes the context grid that the calling contract
/// passed to `eval4` as a 2D `bytes32` matrix indexed by `(i, j)` via this
/// opcode. The interpreter does NOT authenticate, validate, or otherwise
/// inspect the contents of the context. It returns whatever the caller
/// supplied at the requested indices, with OOB protection from Solidity's
/// array bounds.
///
/// Trust model:
/// - The CALLING CONTRACT is the authentication boundary. It MUST validate
///   any signed payloads, verify signer identity, enforce that the
///   context grid it builds reflects authenticated state, and reject
///   replay before invoking the interpreter. Anything an attacker can put
///   into the context grid IS the input the expression sees.
/// - The EXPRESSION must enforce its own semantic constraints over the
///   context it reads: deadlines (e.g. block.timestamp comparisons),
///   nonces (via `get`/`set` with the store), and any per-signer logic.
///   `context` reads alone do not prove authenticity — only structure.
///
/// Integrators MUST treat the context matrix as adversary-controlled
/// unless their calling contract has explicitly authenticated each cell.
library LibOpContext {
    /// @notice `context` integrity check. Requires 0 inputs and produces 1 output.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        // Context doesn't have any inputs. The operand defines the reads.
        // Unfortunately we don't know the shape of the context that we will
        // receive at runtime, so we can't check the reads at integrity time.
        return (0, 1);
    }

    /// @notice `context` opcode. Reads a value from the context matrix at operand-specified indices.
    /// @param state The interpreter state containing the context matrix.
    /// @param operand Encodes the column (low byte) and row (second byte) indices.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory state, OperandV2 operand, Pointer stackTop) internal pure returns (Pointer) {
        uint256 i = uint256(OperandV2.unwrap(operand) & bytes32(uint256(0xFF)));
        uint256 j = uint256((OperandV2.unwrap(operand) >> 8) & bytes32(uint256(0xFF)));
        // We want these indexes to be checked at runtime for OOB accesses
        // because we don't know the shape of the context at compile time.
        // Solidity handles that for us as long as we don't invoke yul for the
        // reads.
        bytes32 v = state.context[i][j];
        assembly ("memory-safe") {
            stackTop := sub(stackTop, 0x20)
            mstore(stackTop, v)
        }
        return stackTop;
    }

    /// @notice Reference implementation of `context` for testing.
    /// @param state The interpreter state containing the context matrix.
    /// @param operand Encodes the column (low byte) and row (second byte) indices.
    /// @return outputs The output values to push onto the stack.
    function referenceFn(InterpreterState memory state, OperandV2 operand, StackItem[] memory)
        internal
        pure
        returns (StackItem[] memory outputs)
    {
        uint256 i = uint256(OperandV2.unwrap(operand) & bytes32(uint256(0xFF)));
        uint256 j = uint256((OperandV2.unwrap(operand) >> 8) & bytes32(uint256(0xFF)));
        // We want these indexes to be checked at runtime for OOB accesses
        // because we don't know the shape of the context at compile time.
        // Solidity handles that for us as long as we don't invoke yul for the
        // reads.
        bytes32 v = state.context[i][j];
        outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(v);
        return outputs;
    }
}
