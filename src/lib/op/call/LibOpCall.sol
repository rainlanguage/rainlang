// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OperandV2} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {LibBytecode} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";
import {LibEval} from "../../eval/LibEval.sol";
import {CallOutputsExceedSource, CallInputsMismatchSource} from "../../../error/ErrIntegrity.sol";

/// @title LibOpCall
/// @notice Contains the call operation. This allows sources to be treated in a
/// function-like manner. Primarily intended as a way for expression authors to
/// create reusable logic inline with their expression, in a way that mimics how
/// words and stack consumption works at the Solidity level.
///
/// Similarities between `call` and a traditional function:
/// - The source is called with a set of 0+ inputs.
/// - The source returns a set of 0+ outputs.
/// - The source has a fixed number of inputs and outputs.
/// - When the source executes it has its own stack/scope.
/// - Sources use lexical scoping rules for named LHS items.
/// - The source can be called from multiple places.
/// - The source can `call` other sources.
/// - The source is stateless across calls
///   (although it can use words like get/set to read/write external state).
/// - The caller and callee have to agree on the number of inputs
///   (but not outputs, see below).
/// - Generally speaking, the behaviour of a source can be reasoned about
///   without needing to know the context in which it is called. Which is the
///   basic requirement for reusability.
///
/// Differences between `call` and a traditional function:
/// - The caller defines the number of outputs to be returned, NOT the callee.
///   This is because the caller is responsible for allocating space on the
///   stack for the outputs, and the callee is responsible for providing the
///   outputs. The only limitation is that the caller cannot request more
///   outputs than the callee has available. This means that two calls to the
///   same source can return different numbers of outputs in different contexts.
/// - The inputs to a source are considered to be the top of the callee's stack
///   from the perspective of the caller. This means that the inputs are eligible
///   to be read as outputs, if the caller chooses to do so.
/// - The sources are not named, they are identified by their index in the
///   bytecode. Tooling can provide sugar over this but the underlying
///   representation is just an index.
/// - Sources are not "first class" like functions often are, i.e. they cannot
///   be passed as arguments to other sources or otherwise be treated as values.
/// - Recursion is not supported. This is because currently there is no laziness
///   in the interpreter, so a recursive call would result in an infinite loop
///   unconditionally (even when wrapped in an `if`). This may change in the
///   future.
/// - The memory allocation for a source must be known at compile time.
/// - There's no way to return early from a source.
///
/// The order of inputs and outputs is designed so that the visual representation
/// of a source call matches the visual representation of a function call. This
/// requires some reversals of order "under the hood" while copying data around
/// but it makes the behaviour of `call` more intuitive.
///
/// Illustrative example:
/// ```
/// /* Final result */
/// /* a = 2 */
/// /* b = 9 */
/// a b: call<1 2>(10 5); ten five:, a b: int-div(ten five) 9;
/// ```
library LibOpCall {
    /// @notice Validates a `call` operand against the bytecode at integrity-check
    /// time. Extracts `sourceIndex` (low 16 bits) and `outputs` (bits 20+)
    /// from the operand.
    ///
    /// `sourceInputsOutputsLength` reverts with `SourceIndexOutOfBounds` if
    /// `sourceIndex` exceeds the bytecode's source count. This is the only
    /// bounds check protecting the assembly access in `run`, which indexes
    /// into `stackBottoms` via raw pointer arithmetic.
    ///
    /// Reverts with `CallOutputsExceedSource` if the caller requests more
    /// outputs than the callee source provides.
    /// @param state The current integrity check state containing the bytecode.
    /// @param operand Encodes sourceIndex (low 16 bits), inputs (bits 16–19),
    /// and outputs (bits 20+).
    /// @return The number of inputs and outputs for stack tracking.
    function integrity(IntegrityCheckState memory state, OperandV2 operand) internal pure returns (uint256, uint256) {
        uint256 sourceIndex = uint256(OperandV2.unwrap(operand) & bytes32(uint256(0xFFFF)));
        uint256 outputs = uint256(OperandV2.unwrap(operand) >> 0x14) & 0x0F;

        uint256 operandInputs = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;

        (uint256 sourceInputs, uint256 sourceOutputs) =
            LibBytecode.sourceInputsOutputsLength(state.bytecode, sourceIndex);

        if (operandInputs != sourceInputs) {
            revert CallInputsMismatchSource(operandInputs, sourceInputs);
        }
        if (sourceOutputs < outputs) {
            revert CallOutputsExceedSource(sourceOutputs, outputs);
        }

        return (sourceInputs, outputs);
    }

    /// @notice Executes a call to another source within the same expression.
    ///
    /// 1. Extracts `sourceIndex`, `inputs`, and `outputs` from the operand.
    /// 2. Looks up the callee's stack bottom from `state.stackBottoms` and
    ///    copies `inputs` values from the caller's stack to the callee's
    ///    stack in reverse order (so the first input to `call` becomes the
    ///    bottom of the callee's stack).
    /// 3. Saves and swaps `state.sourceIndex`, then runs `evalLoop` for the
    ///    callee source.
    /// 4. Copies `outputs` values from the callee's stack back to the
    ///    caller's stack, then restores `state.sourceIndex`.
    ///
    /// `stackBottoms[sourceIndex]` is accessed via assembly pointer arithmetic
    /// (no Solidity bounds check). This is safe because `integrity` validates
    /// `sourceIndex` against the bytecode via
    /// `LibBytecode.sourceInputsOutputsLength`, which reverts with
    /// `SourceIndexOutOfBounds` for invalid indices. Bytecode is immutable
    /// once serialized so the index cannot become stale.
    /// @param state The interpreter state containing the stack bottoms and bytecode.
    /// @param operand Encodes sourceIndex (low 16 bits), inputs (bits 16–19),
    /// and outputs (bits 20+).
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory state, OperandV2 operand, Pointer stackTop) internal view returns (Pointer) {
        // Extract config from the operand.
        uint256 sourceIndex = uint256(OperandV2.unwrap(operand) & bytes32(uint256(0xFFFF)));
        uint256 inputs = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;
        uint256 outputs = uint256(OperandV2.unwrap(operand) >> 0x14) & 0x0F;

        // Copy inputs in. The inputs have to be copied in reverse order so that
        // the top of the stack from the perspective of `call`, i.e. the first
        // input to call, is the bottom of the stack from the perspective of the
        // callee.
        Pointer[] memory stackBottoms = state.stackBottoms;
        Pointer evalStackBottom;
        Pointer evalStackTop;
        assembly ("memory-safe") {
            evalStackBottom := mload(add(stackBottoms, mul(add(sourceIndex, 1), 0x20)))
            evalStackTop := evalStackBottom
            let end := add(stackTop, mul(inputs, 0x20))
            for {} lt(stackTop, end) { stackTop := add(stackTop, 0x20) } {
                evalStackTop := sub(evalStackTop, 0x20)
                mstore(evalStackTop, mload(stackTop))
            }
        }

        // Keep a copy of the current source index so that we can restore it
        // after the call.
        uint256 currentSourceIndex = state.sourceIndex;

        // Set the state to the source we are calling.
        state.sourceIndex = sourceIndex;

        // Run the eval loop.
        evalStackTop = LibEval.evalLoop(state, currentSourceIndex, evalStackTop, evalStackBottom);

        // Restore the source index in the state.
        state.sourceIndex = currentSourceIndex;

        // Copy outputs out.
        assembly ("memory-safe") {
            stackTop := sub(stackTop, mul(outputs, 0x20))
            let end := add(evalStackTop, mul(outputs, 0x20))
            let cursor := stackTop
            for {} lt(evalStackTop, end) {
                cursor := add(cursor, 0x20)
                evalStackTop := add(evalStackTop, 0x20)
            } { mstore(cursor, mload(evalStackTop)) }
        }

        return stackTop;
    }
}
