// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Pointer} from "rain.solmem/lib/LibPointer.sol";

import {
    OpcodeOutOfRange,
    StackAllocationMismatch,
    StackOutputsMismatch,
    StackUnderflow,
    StackUnderflowHighwater
} from "../../error/ErrIntegrity.sol";
import {BadOpInputsLength, BadOpOutputsLength} from "rain.interpreter.interface/error/ErrIntegrity.sol";
import {LibBytecode} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";
import {OperandV2} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {OPCODE_FUNCTION_POINTER_SHIFT} from "../eval/LibEval.sol";

/// @notice Tracks the state of the integrity check walk over a single source.
/// @param stackIndex Current logical stack depth. Increases with opcode
/// outputs and decreases with opcode inputs.
/// @param stackMaxIndex Peak stack depth seen so far, used to verify the
/// bytecode-declared stack allocation.
/// @param readHighwater Lowest stack index that opcodes are allowed to read
/// from via consumption. After an opcode produces multiple outputs, the
/// highwater advances to prevent subsequent opcodes from consuming below
/// the multi-output region, which would leave orphaned values. Read-only
/// access (e.g. the `stack` opcode) is permitted below the highwater
/// because copying does not create aliasing.
/// @param constants The constants array for the expression, passed through
/// to opcode integrity functions that need it.
/// @param opIndex Sequential counter of opcodes processed, used for error
/// reporting.
/// @param bytecode The full bytecode containing all sources, retained so
/// opcode integrity functions can inspect other sources (e.g. call).
struct IntegrityCheckState {
    uint256 stackIndex;
    uint256 stackMaxIndex;
    uint256 readHighwater;
    bytes32[] constants;
    uint256 opIndex;
    bytes bytecode;
}

library LibIntegrityCheck {
    using LibIntegrityCheck for IntegrityCheckState;

    /// @notice Builds a fresh `IntegrityCheckState` for a single source. The initial
    /// stack index, max index, and read highwater are all set to `stackIndex`
    /// (the number of source inputs), so that source inputs are treated as
    /// immutable during the integrity walk.
    /// @param bytecode The full bytecode containing all sources.
    /// @param stackIndex The number of source inputs, used as the initial
    /// stack depth and read highwater.
    /// @param constants The constants array for the expression.
    /// @return The initialized integrity check state.
    function newState(bytes memory bytecode, uint256 stackIndex, bytes32[] memory constants)
        internal
        pure
        returns (IntegrityCheckState memory)
    {
        return IntegrityCheckState(
            // stackIndex
            stackIndex,
            // stackMaxIndex
            stackIndex,
            // highwater (source inputs are always immutable)
            stackIndex,
            // constants
            constants,
            // opIndex
            0,
            // bytecode
            bytecode
        );
    }

    /// @notice Walks every opcode in every source of `bytecode`, calling each opcode's
    /// integrity function via `fPointers` to compute expected inputs/outputs.
    /// Validates that the computed IO matches the bytecode-declared IO, that
    /// the stack never underflows or drops below the read highwater, and that
    /// the final stack depth matches the declared allocation and outputs.
    /// Reverts on any mismatch. Returns a packed `io` byte array with two
    /// bytes per source (inputs, outputs).
    ///
    /// This is the single validation authority for bytecode correctness.
    /// Opcode `integrity()` functions report accurate stack IO here;
    /// opcode `run()` functions trust that validation has already passed
    /// and do not duplicate these checks, keeping runtime gas costs low.
    /// @param fPointers Packed 2-byte function pointers for each opcode's
    /// integrity function.
    /// @param bytecode The full bytecode containing all sources to check.
    /// @param constants The constants array for the expression.
    /// @return io Packed byte array with two bytes per source encoding
    /// (inputs, outputs).
    //slither-disable-next-line cyclomatic-complexity
    function integrityCheck2(bytes memory fPointers, bytes memory bytecode, bytes32[] memory constants)
        internal
        view
        returns (bytes memory io)
    {
        unchecked {
            uint256 sourceCount = LibBytecode.sourceCount(bytecode);

            uint256 fPointersStart;
            uint256 fsCount;
            assembly ("memory-safe") {
                fPointersStart := add(fPointers, 0x20)
                fsCount := div(mload(fPointers), 2)
            }

            // Ensure that the bytecode has no out of bounds pointers BEFORE we
            // start attempting to iterate over opcodes. This ensures the
            // integrity of the source count, relative offset pointers,
            // ops count per source, and that there is no garbage bytes at the
            // end or between these things. Basically everything structural about
            // the bytecode is confirmed here.
            LibBytecode.checkNoOOBPointers(bytecode);

            io = new bytes(sourceCount * 2);
            uint256 ioCursor;
            assembly ("memory-safe") {
                ioCursor := add(io, 0x20)
            }

            // Run the integrity check over each source. This needs to ensure
            // the integrity of each source's inputs, outputs, and stack
            // allocation, as well as the integrity of the bytecode itself on
            // a per-opcode basis, according to each opcode's implementation.
            for (uint256 i = 0; i < sourceCount; i++) {
                (uint256 inputsLength, uint256 outputsLength) = LibBytecode.sourceInputsOutputsLength(bytecode, i);
                // Inputs and outputs are 1 byte each. This is enforced by the
                // structure of the bytecode itself.
                assembly ("memory-safe") {
                    mstore8(ioCursor, inputsLength)
                    mstore8(add(ioCursor, 1), outputsLength)
                    ioCursor := add(ioCursor, 2)
                }

                IntegrityCheckState memory state = LibIntegrityCheck.newState(bytecode, inputsLength, constants);

                // Have low 4 bytes of cursor overlap the first op, skipping the
                // prefix.
                uint256 cursor = Pointer.unwrap(LibBytecode.sourcePointer(bytecode, i)) - 0x18;
                uint256 end = cursor + LibBytecode.sourceOpsCount(bytecode, i) * 4;

                while (cursor < end) {
                    OperandV2 operand;
                    uint256 bytecodeOpInputs;
                    uint256 bytecodeOpOutputs;
                    uint256 opcodeIndex;
                    function(IntegrityCheckState memory, OperandV2) view returns (uint256, uint256) f;
                    assembly ("memory-safe") {
                        let word := mload(cursor)
                        opcodeIndex := byte(28, word)
                        // 3 bytes mask.
                        operand := and(word, 0xFFFFFF)
                        let ioByte := byte(29, word)
                        bytecodeOpInputs := and(ioByte, 0x0F)
                        bytecodeOpOutputs := shr(4, ioByte)
                    }
                    if (opcodeIndex >= fsCount) {
                        revert OpcodeOutOfRange(state.opIndex, opcodeIndex, fsCount);
                    }
                    assembly ("memory-safe") {
                        f := shr(OPCODE_FUNCTION_POINTER_SHIFT, mload(add(fPointersStart, mul(opcodeIndex, 2))))
                    }
                    (uint256 calcOpInputs, uint256 calcOpOutputs) = f(state, operand);
                    if (calcOpInputs != bytecodeOpInputs) {
                        revert BadOpInputsLength(state.opIndex, calcOpInputs, bytecodeOpInputs);
                    }
                    if (calcOpOutputs != bytecodeOpOutputs) {
                        revert BadOpOutputsLength(state.opIndex, calcOpOutputs, bytecodeOpOutputs);
                    }

                    if (calcOpInputs > state.stackIndex) {
                        revert StackUnderflow(state.opIndex, state.stackIndex, calcOpInputs);
                    }
                    state.stackIndex -= calcOpInputs;

                    // The stack index can't move below the highwater.
                    if (state.stackIndex < state.readHighwater) {
                        revert StackUnderflowHighwater(state.opIndex, state.stackIndex, state.readHighwater);
                    }

                    // Let's assume that sane opcode implementations don't
                    // overflow uint256 due to their outputs.
                    state.stackIndex += calcOpOutputs;

                    // Ensure the max stack index is updated if needed.
                    if (state.stackIndex > state.stackMaxIndex) {
                        state.stackMaxIndex = state.stackIndex;
                    }

                    // If there are multiple outputs the highwater MUST move.
                    if (calcOpOutputs > 1) {
                        state.readHighwater = state.stackIndex;
                    }

                    state.opIndex++;
                    cursor += 4;
                }

                // The final stack max index MUST match the bytecode allocation.
                if (state.stackMaxIndex != LibBytecode.sourceStackAllocation(bytecode, i)) {
                    revert StackAllocationMismatch(state.stackMaxIndex, LibBytecode.sourceStackAllocation(bytecode, i));
                }

                // The final stack index MUST match the bytecode source outputs.
                if (state.stackIndex != outputsLength) {
                    revert StackOutputsMismatch(state.stackIndex, outputsLength);
                }
            }
        }
    }
}
