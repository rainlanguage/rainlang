// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {MemoryKV} from "rain.lib.memkv/lib/LibMemoryKV.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {LibMemCpy} from "rain.solmem/lib/LibMemCpy.sol";
import {LibBytes} from "rain.solmem/lib/LibBytes.sol";
import {FullyQualifiedNamespace} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {IInterpreterStoreV3} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";

import {InterpreterState} from "./LibInterpreterState.sol";
import {SOURCE_OFFSET_SHIFT} from "../eval/LibEval.sol";

library LibInterpreterStateDataContract {
    using LibBytes for bytes;

    /// @notice Returns the total byte size needed to serialize `bytecode` and
    /// `constants` into a single contiguous memory region. The layout is:
    /// `[constants length][constants data...][bytecode length][bytecode data...]`.
    /// Uses unchecked arithmetic — the caller MUST ensure the in-memory length
    /// fields of `bytecode` and `constants` are not corrupt, otherwise the
    /// multiplication or addition can silently overflow.
    /// @param bytecode The bytecode to serialize.
    /// @param constants The constants array to serialize.
    /// @return size The total byte size of the serialized representation.
    function serializeSize(bytes memory bytecode, bytes32[] memory constants) internal pure returns (uint256 size) {
        unchecked {
            // bytecode length + constants length * 0x20 + 0x40 for both the bytecode and constants length words.
            size = bytecode.length + constants.length * 0x20 + 0x40;
        }
    }

    /// @notice Writes `constants` (with length prefix) then `bytecode` (with length
    /// prefix) into the memory region starting at `cursor`. The caller must
    /// ensure `cursor` points to a region of at least `serializeSize` bytes.
    /// @param cursor Pointer to the start of the destination memory region.
    /// @param bytecode The bytecode to serialize.
    /// @param constants The constants array to serialize.
    function unsafeSerialize(Pointer cursor, bytes memory bytecode, bytes32[] memory constants) internal pure {
        unchecked {
            // Copy constants into place with length.
            assembly ("memory-safe") {
                for {
                    let constantsCursor := constants
                    let constantsEnd := add(constantsCursor, mul(0x20, add(mload(constants), 1)))
                } lt(constantsCursor, constantsEnd) {
                    constantsCursor := add(constantsCursor, 0x20)
                    cursor := add(cursor, 0x20)
                } { mstore(cursor, mload(constantsCursor)) }
            }
            // Copy the bytecode into place with length.
            LibMemCpy.unsafeCopyBytesTo(bytecode.startPointer(), cursor, bytecode.length + 0x20);
        }
    }

    /// @notice Reconstructs an `InterpreterState` from a previously serialized byte
    /// array. References the constants and bytecode arrays in-place (no copy).
    /// Allocates a fresh stack for each source according to the bytecode's
    /// declared stack allocation, and returns a fully populated state ready
    /// for evaluation.
    /// @param serialized The serialized byte array produced by
    /// `unsafeSerialize`.
    /// @param sourceIndex The index of the source to evaluate.
    /// @param namespace The fully qualified namespace for store reads/writes.
    /// @param store The interpreter store contract for persistent state.
    /// @param context The 2D context array passed by the caller.
    /// @param fs The packed function pointer table for opcode dispatch.
    /// @return The fully populated interpreter state ready for evaluation.
    function unsafeDeserialize(
        bytes memory serialized,
        uint256 sourceIndex,
        FullyQualifiedNamespace namespace,
        IInterpreterStoreV3 store,
        bytes32[][] memory context,
        bytes memory fs
    ) internal pure returns (InterpreterState memory) {
        unchecked {
            Pointer cursor;
            assembly ("memory-safe") {
                cursor := add(serialized, 0x20)
            }

            // Reference the constants array as-is and move cursor past it.
            bytes32[] memory constants;
            assembly ("memory-safe") {
                constants := cursor
                cursor := add(cursor, mul(0x20, add(mload(cursor), 1)))
            }

            // Reference the bytecode array as-is.
            bytes memory bytecode;
            assembly ("memory-safe") {
                bytecode := cursor
            }

            // Build all the stacks.
            Pointer[] memory stackBottoms;
            assembly ("memory-safe") {
                cursor := add(cursor, 0x20)
                let stacksLength := byte(0, mload(cursor))
                cursor := add(cursor, 1)
                let sourcesStart := add(cursor, mul(stacksLength, 2))

                // Allocate the memory for stackBottoms.
                // We don't need to zero this because we're about to write to it.
                stackBottoms := mload(0x40)
                mstore(stackBottoms, stacksLength)
                mstore(0x40, add(stackBottoms, mul(add(stacksLength, 1), 0x20)))

                // Allocate each stack and point to it.
                let stacksCursor := add(stackBottoms, 0x20)
                for { let i := 0 } lt(i, stacksLength) {
                    i := add(i, 1)
                    // Move over the 2 byte source pointer.
                    cursor := add(cursor, 2)
                    // Move the stacks cursor forward.
                    stacksCursor := add(stacksCursor, 0x20)
                } {
                    // The stack size is in the prefix of the source data, which
                    // is behind a relative pointer in the bytecode prefix.
                    let sourcePointer := add(sourcesStart, shr(SOURCE_OFFSET_SHIFT, mload(cursor)))
                    // Stack size is the second byte of the source prefix.
                    let stackSize := byte(1, mload(sourcePointer))

                    // Allocate the stack.
                    // We don't need to zero the stack because the interpreter
                    // assumes values above the stack top are dirty anyway.
                    let stack := mload(0x40)
                    mstore(stack, stackSize)
                    let stackBottom := add(stack, mul(add(stackSize, 1), 0x20))
                    mstore(0x40, stackBottom)

                    // Point to the stack bottom
                    mstore(stacksCursor, stackBottom)
                }
            }

            return InterpreterState(
                stackBottoms, constants, sourceIndex, MemoryKV.wrap(0), namespace, store, context, bytecode, fs
            );
        }
    }
}
