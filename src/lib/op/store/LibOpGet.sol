// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {MemoryKVKey, MemoryKVVal, MemoryKV, LibMemoryKV} from "rain.lib.memkv/lib/LibMemoryKV.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";

/// @title LibOpGet
/// @notice Opcode for reading from storage.
library LibOpGet {
    using LibMemoryKV for MemoryKV;

    /// @notice `get` integrity check. Requires 1 input (key) and produces 1 output (value).
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        // Always 1 input. The key. `hash()` is recommended to build compound
        // keys.
        return (1, 1);
    }

    /// @notice Implements runtime behaviour of the `get` opcode. Attempts to lookup the
    /// key in the memory key/value store then falls back to the interpreter's
    /// storage interface as an external call. If the key is not found in either,
    /// the value will fallback to `0` as per default Solidity/EVM behaviour.
    /// @param state The interpreter state of the current eval.
    /// @param stackTop Pointer to the current stack top.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory state, OperandV2, Pointer stackTop) internal view returns (Pointer) {
        bytes32 key;
        assembly ("memory-safe") {
            key := mload(stackTop)
        }
        (uint256 exists, MemoryKVVal value) = state.stateKV.get(MemoryKVKey.wrap(key));

        // Cache MISS, get from external store.
        if (exists == 0) {
            bytes32 storeValue = state.store.get(state.namespace, key);

            // Push fetched value to memory to make subsequent lookups on the
            // same key find a cache HIT. Note: this means read-only keys will
            // also be persisted to the store at the end of eval, paying an
            // unnecessary SSTORE. In practice the gas saved by caching
            // repeated reads outweighs this cost.
            state.stateKV = state.stateKV.set(MemoryKVKey.wrap(key), MemoryKVVal.wrap(storeValue));

            assembly ("memory-safe") {
                mstore(stackTop, storeValue)
            }
        }
        // Cache HIT.
        else {
            assembly ("memory-safe") {
                mstore(stackTop, value)
            }
        }

        return stackTop;
    }

    /// @notice Reference implementation of `get` for testing.
    /// @param state The interpreter state containing the store and KV cache.
    /// @param inputs The input values from the stack.
    /// @return The output values to push onto the stack.
    function referenceFn(InterpreterState memory state, OperandV2, StackItem[] memory inputs)
        internal
        view
        returns (StackItem[] memory)
    {
        bytes32 key = StackItem.unwrap(inputs[0]);
        (uint256 exists, MemoryKVVal value) = state.stateKV.get(MemoryKVKey.wrap(key));
        StackItem[] memory outputs = new StackItem[](1);
        // Cache MISS, get from external store.
        if (exists == 0) {
            bytes32 storeValue = state.store.get(state.namespace, key);

            // Push fetched value to memory to make subsequent lookups on the
            // same key find a cache HIT.
            state.stateKV = state.stateKV.set(MemoryKVKey.wrap(key), MemoryKVVal.wrap(storeValue));

            outputs[0] = StackItem.wrap(storeValue);
        }
        // Cache HIT.
        else {
            outputs[0] = StackItem.wrap(MemoryKVVal.unwrap(value));
        }

        return outputs;
    }
}
