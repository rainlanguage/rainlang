// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ParseState} from "./LibParseState.sol";

/// @title LibParseStackName
/// @notice Stack names are stored as a singly-linked list of 256-bit nodes in memory.
/// Each node packs three fields into a single word:
///   - bits [255:32] — 224-bit fingerprint (keccak256 of the name, top 224 bits)
///   - bits [31:16]  — stack index assigned when the name was first pushed
///   - bits [15:0]   — memory pointer to the next node (0 = end of list)
///
/// A 256-position bloom filter (`stackNameBloom`) provides a fast-path reject
/// for names that have never been pushed. The bloom key is the low 8 bits of
/// the fingerprint, giving a single bit per name. On a bloom miss the linked
/// list is not traversed at all. On a bloom hit (true or false positive) the
/// list is walked linearly comparing 224-bit fingerprints until a match is
/// found or the list is exhausted. Because n is small (number of LHS names in
/// one expression) the linear walk is cheap even on false positives.
library LibParseStackName {
    /// @notice Push a word onto the stack name linked list. If the word already exists
    /// (by fingerprint), returns the existing index without allocating a new
    /// node. Otherwise allocates a new node at the free memory pointer and
    /// prepends it to the list.
    /// @param state The parser state containing the stack names.
    /// @param word The word to push onto the stack name stack.
    /// @return exists Whether the word already existed.
    /// @return index The new index after the word was pushed. Will be unchanged
    /// if the word already existed.
    function pushStackName(ParseState memory state, bytes32 word) internal pure returns (bool exists, uint256 index) {
        unchecked {
            (exists, index) = stackNameIndex(state, word);
            if (!exists) {
                uint256 fingerprint;
                uint256 ptr;
                uint256 oldStackNames = state.stackNames;
                assembly ("memory-safe") {
                    mstore(0, word)
                    fingerprint := and(keccak256(0, 0x20), not(0xFFFFFFFF))
                    ptr := mload(0x40)
                    mstore(ptr, oldStackNames)
                    mstore(0x40, add(ptr, 0x20))
                }
                // Add the start of line height to the LHS line parse count.
                // forge-lint: disable-next-line(mixed-case-variable)
                uint256 stackLHSIndex = state.topLevel1 & 0xFF;
                state.stackNames = fingerprint | (stackLHSIndex << 0x10) | ptr;
                index = stackLHSIndex + 1;
            }
        }
    }

    /// @notice Look up a word in the stack name linked list. First checks the bloom
    /// filter for an early exit when the name is definitely absent. On a bloom
    /// hit, walks the linked list comparing 224-bit fingerprints. Also updates
    /// the bloom filter so that future lookups for this word will hit.
    /// @param state The parser state containing the stack names.
    /// @param word The word to look up.
    /// @return exists Whether the word was found.
    /// @return index The index of the word in the stack.
    function stackNameIndex(ParseState memory state, bytes32 word) internal pure returns (bool exists, uint256 index) {
        uint256 fingerprint;
        uint256 stackNames = state.stackNames;
        uint256 stackNameBloom = state.stackNameBloom;
        uint256 bloom;
        assembly ("memory-safe") {
            mstore(0, word)
            fingerprint := shr(0x20, keccak256(0, 0x20))
            //slither-disable-next-line incorrect-shift
            bloom := shl(and(fingerprint, 0xFF), 1)

            // If the bloom matches then maybe the stack name is in the stack.
            if and(bloom, stackNameBloom) {
                for { let ptr := and(stackNames, 0xFFFF) } iszero(iszero(ptr)) {
                    stackNames := mload(ptr)
                    ptr := and(stackNames, 0xFFFF)
                } {
                    if eq(fingerprint, shr(0x20, stackNames)) {
                        exists := true
                        index := and(shr(0x10, stackNames), 0xFFFF)
                        break
                    }
                }
            }
        }
        state.stackNameBloom = bloom | stackNameBloom;
    }
}
