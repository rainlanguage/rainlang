// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {MemoryKV} from "rain.lib.memkv/lib/LibMemoryKV.sol";
import {
    FullyQualifiedNamespace,
    IInterpreterStoreV3
} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

/// @dev Deterministic address used as the `staticcall` target for stack trace
/// emissions. Derived from a domain-specific keccak hash so it cannot collide
/// with a deployed contract. The call always fails (no code at this address),
/// but the calldata is visible in traces for debugging.
address constant STACK_TRACER = address(uint160(uint256(keccak256("rain.interpreter.stack-tracer.0"))));

/// @notice Runtime state threaded through the eval loop and all opcode
/// implementations. Built once per `eval4` call from deserialized
/// bytecode, caller-provided context, and store configuration.
/// @param stackBottoms Bottom pointer for each source's stack. The eval
/// loop starts the stack top here and grows downward as values are pushed.
/// @param constants Immutable values embedded in the expression at deploy
/// time. Opcodes index into this array via their operand.
/// @param sourceIndex Index of the source currently being evaluated.
/// @param stateKV Ephemeral key-value store scoped to a single eval call.
/// Opcode `get`/`set` read and write here; flushed to the on-chain store
/// after eval completes.
/// @param namespace Fully qualified namespace that sandboxes all store
/// reads and writes for this evaluation.
/// @param store On-chain key-value store contract. Written to after eval
/// if `stateKV` contains dirty keys.
/// @param context Two-dimensional array of caller-supplied read-only data.
/// Rows and columns are accessed by the `context` opcode via its operand.
/// @param bytecode Serialized sources produced by the parser and deployed
/// by the expression deployer. Contains opcode + operand pairs packed into
/// 4-byte words, prefixed per-source with stack allocation metadata.
/// @param fs Function pointers table for opcode dispatch. Each 2-byte
/// entry is an offset into the contract code used by the eval loop to
/// jump to the correct opcode implementation.
struct InterpreterState {
    Pointer[] stackBottoms;
    bytes32[] constants;
    uint256 sourceIndex;
    //forge-lint: disable-next-line(mixed-case-variable)
    MemoryKV stateKV;
    FullyQualifiedNamespace namespace;
    IInterpreterStoreV3 store;
    bytes32[][] context;
    bytes bytecode;
    bytes fs;
}

library LibInterpreterState {
    /// @notice Converts pre-allocated stack arrays into an array of bottom pointers.
    /// Each stack's bottom pointer is the address just past its last element,
    /// i.e. `array + 0x20 * (length + 1)`. The eval loop uses these pointers
    /// as the starting stack top, growing downward as values are pushed.
    /// @param stacks The pre-allocated stack arrays, one per source.
    /// @return The array of bottom pointers, one per stack.
    function stackBottoms(StackItem[][] memory stacks) internal pure returns (Pointer[] memory) {
        Pointer[] memory bottoms = new Pointer[](stacks.length);
        assembly ("memory-safe") {
            for {
                let cursor := add(stacks, 0x20)
                let end := add(cursor, mul(mload(stacks), 0x20))
                let bottomsCursor := add(bottoms, 0x20)
            } lt(cursor, end) {
                cursor := add(cursor, 0x20)
                bottomsCursor := add(bottomsCursor, 0x20)
            } {
                let stack := mload(cursor)
                let stackBottom := add(stack, mul(0x20, add(mload(stack), 1)))
                mstore(bottomsCursor, stackBottom)
            }
        }
        return bottoms;
    }

    /// @notice Does something that a full node can easily track in its traces that isn't
    /// an event. Specifically, it calls the tracer contract with the memory
    /// region between `stackTop` and `stackBottom` as an argument. The parent
    /// source index and source index are packed as two uint16 values into a
    /// 4 byte prefix to the memory region, so that it will be interpreted as a
    /// function selector by most tooling that is expecting ABI encoded data.
    ///
    /// The tracer contract doesn't exist, the whole point is that the call will
    /// be a no-op, but it will be visible in traces and unambiguous as no other
    /// call will be made to the tracer contract for any reason other than
    /// tracing stacks.
    ///
    /// Note that the trace is a literal memory region, no ABI encoding or other
    /// processing is done. The structure is 2 bytes of parent source index
    /// followed by 2 bytes of source index, then 32 byte items for each stack
    /// item, in order from top to bottom.
    ///
    /// There are several reasons we do this instead of emitting an event:
    /// - It's cheaper. Way cheaper in the case of large stacks. There is a one
    ///   time 2600 gas cost to warm the tracer, then all subsequent calls are
    ///   just 100 gas + memory expansion cost. Using an empty contract means
    ///   there's no execution cost.
    ///   (vs. e.g. a solidity contract that would at least attempt a dispatch)
    ///   Meanwhile, emitting an event costs 375 gas plus 8 gas per byte, plus
    ///   the cost of the memory expansion.
    ///   Let's say we have 50 stack items spread over 5 calls:
    ///   - Using the tracer:
    ///     ( 2600 + 100 * 4 ) + (51 ** 2) / 512 + (3 * 51)
    ///     = 3000 + 2601 / 512 + 153
    ///     = 3000 + 5 + 153
    ///     ~= 3158
    ///   - Using an event (assuming same memory expansion cost):
    ///     (375 * 5) + (8 * 50 * 32) + 4
    ///     = 1875 + 12800 + 4
    ///     = 14679 (nearly 5x the cost!)
    /// - Events cannot be emitted from view functions, so we would have to
    ///   either abandon our view eval (security risk) or return every internal
    ///   stack back to the caller, to have it handle the event emission. This
    ///   would be both complex and onerous for caller implementations, and make
    ///   it much harder for tooling/consumers to reliably find all the data, as
    ///   it would be spread across callers in potentially inconsistent events.
    /// @param parentSourceIndex The source index of the calling source.
    /// @param sourceIndex The source index of the source that was evaluated.
    /// @param stackTop Pointer to the top of the stack after evaluation.
    /// @param stackBottom Pointer to the bottom of the stack.
    function stackTrace(uint256 parentSourceIndex, uint256 sourceIndex, Pointer stackTop, Pointer stackBottom)
        internal
        view
    {
        address tracer = STACK_TRACER;
        assembly ("memory-safe") {
            // We are mutating memory in place to avoid allocation, copying, etc.
            let beforePtr := sub(stackTop, 0x20)
            // We need to save the value at the pointer before we overwrite it.
            let before := mload(beforePtr)
            mstore(beforePtr, or(shl(0x10, and(parentSourceIndex, 0xFFFF)), and(sourceIndex, 0xFFFF)))
            // We don't care about success, we just want to call the tracer.
            pop(staticcall(gas(), tracer, sub(stackTop, 4), add(sub(stackBottom, stackTop), 4), 0, 0))
            // Restore the value at the pointer that we mutated above.
            mstore(beforePtr, before)
        }
    }
}
