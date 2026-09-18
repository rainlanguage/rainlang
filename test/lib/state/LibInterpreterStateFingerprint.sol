// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {InterpreterState} from "../../../src/lib/state/LibInterpreterState.sol";
import {LibMemoryKV, MemoryKV, MEMORY_KV_EMPTY} from "rain-lib-memkv-0.2.0/src/lib/LibMemoryKV.sol";
import {Arrays} from "@openzeppelin-contracts-5.6.1/utils/Arrays.sol";

/// @title LibInterpreterStateFingerprint
/// @notice Test-only library for computing a keccak256 fingerprint of interpreter
/// state. Used to detect state mutations between evaluation calls.
library LibInterpreterStateFingerprint {
    using LibMemoryKV for MemoryKV;

    /// @notice Hashes every field of `state`, with `stateKV` contributing the
    /// pairs it holds (see `stateKVPairHashes`) instead of its handle word. An
    /// insert or an update moves the fingerprint, and stores holding the same
    /// pairs fingerprint the same wherever they are in memory. `state.stateKV`
    /// is set to `MEMORY_KV_EMPTY` for the encoding and restored before return.
    /// @param state The state to fingerprint.
    /// @return The keccak256 fingerprint.
    function fingerprint(InterpreterState memory state) internal pure returns (bytes32) {
        MemoryKV stateKV = state.stateKV;
        state.stateKV = MEMORY_KV_EMPTY;
        bytes32 result = keccak256(abi.encode(state, stateKVPairHashes(stateKV)));
        state.stateKV = stateKV;
        return result;
    }

    /// @notice The keccak256 of each key/value pair in `kv`, sorted ascending,
    /// so the result depends on the pairs held and not on the order
    /// `toBytes32Array` exports them in.
    /// @param kv The store to hash.
    /// @return One hash per pair, sorted ascending.
    function stateKVPairHashes(MemoryKV kv) internal pure returns (bytes32[] memory) {
        bytes32[] memory kvs = kv.toBytes32Array();
        bytes32[] memory pairHashes = new bytes32[](kvs.length / 2);
        for (uint256 i = 0; i < pairHashes.length; i++) {
            pairHashes[i] = keccak256(abi.encode(kvs[2 * i], kvs[2 * i + 1]));
        }
        return Arrays.sort(pairHashes);
    }
}
