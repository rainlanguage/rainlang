//// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {ParseState, LibParseStackName} from "../../../../src/lib/parse/LibParse.sol";

/// @title LibParseStackNameTest
/// @notice Tests for handling named stack items.
contract LibParseStackNameTest is Test {
    /// Test that we can push and retrieve a stack name.
    function testPushAndRetrieveStackNameSingle(ParseState memory state, bytes32 word) external pure {
        state.lineTracker = 0;
        state.topLevel1 = 0;
        state.stackNames = 0;

        (bool exists, uint256 index) = LibParseStackName.pushStackName(state, word);
        assertFalse(exists);
        assertEq(index, 1);

        state.lineTracker = index;
        state.topLevel1 = index;

        (exists, index) = LibParseStackName.stackNameIndex(state, word);
        assertTrue(exists);
        assertEq(index, 0);
    }

    /// Test that we can push and retrieve two different stack names.
    function testPushAndRetrieveStackNameDouble(ParseState memory state, bytes32 word1, bytes32 word2) external pure {
        vm.assume(word1 != word2);
        state.lineTracker = 0;
        state.topLevel1 = 0;
        state.stackNames = 0;

        (bool exists, uint256 index) = LibParseStackName.pushStackName(state, word1);
        assertFalse(exists);
        assertEq(index, 1);

        state.lineTracker = index;
        state.topLevel1 = index;

        (exists, index) = LibParseStackName.pushStackName(state, word2);
        assertFalse(exists);
        assertEq(index, 2);

        state.lineTracker = index;
        state.topLevel1 = index;

        (exists, index) = LibParseStackName.stackNameIndex(state, word1);
        assertTrue(exists);
        assertEq(index, 0);

        (exists, index) = LibParseStackName.stackNameIndex(state, word2);
        assertTrue(exists);
        assertEq(index, 1);
    }

    /// Test that two identical stack names are not pushed.
    function testPushAndRetrieveStackNameDoubleIdentical(ParseState memory state, bytes32 word) external pure {
        state.lineTracker = 0;
        state.topLevel1 = 0;
        state.stackNames = 0;

        (bool exists, uint256 index) = LibParseStackName.pushStackName(state, word);
        assertFalse(exists);
        assertEq(index, 1);

        state.lineTracker = index;
        state.topLevel1 = index;

        (exists, index) = LibParseStackName.pushStackName(state, word);
        assertTrue(exists);
        assertEq(index, 0);
    }

    /// Look up a word that was never pushed on a populated list.
    function testStackNameNegativeLookup(ParseState memory state, bytes32 word1, bytes32 word2) external pure {
        vm.assume(word1 != word2);
        state.lineTracker = 0;
        state.topLevel1 = 0;
        state.stackNames = 0;
        state.stackNameBloom = 0;

        LibParseStackName.pushStackName(state, word1);
        state.lineTracker = 1;
        state.topLevel1 = 1;

        (bool exists, uint256 index) = LibParseStackName.stackNameIndex(state, word2);
        assertFalse(exists, "word2 should not exist");
        assertEq(index, 0, "index should be 0 on miss");
    }

    /// Construct two words that share the same bloom bit (low 8 bits of the
    /// shifted keccak fingerprint) to force a bloom false positive. Push only
    /// word A, look up word B — the bloom filter says "maybe" but the
    /// linked-list traversal finds no match.
    function testStackNameBloomFalsePositive() external pure {
        // Find two words whose fingerprints share the same low 8 bits.
        bytes32 wordA = bytes32(uint256(0));
        bytes32 wordB;
        uint256 targetBloomBit;
        assembly ("memory-safe") {
            mstore(0, wordA)
            let fpA := shr(0x20, keccak256(0, 0x20))
            targetBloomBit := and(fpA, 0xFF)
        }
        // Brute-force a second word with the same bloom bit.
        for (uint256 i = 1; i < 1000; i++) {
            bytes32 candidate = bytes32(i);
            uint256 bloomBit;
            assembly ("memory-safe") {
                mstore(0, candidate)
                bloomBit := and(shr(0x20, keccak256(0, 0x20)), 0xFF)
            }
            if (bloomBit == targetBloomBit) {
                wordB = candidate;
                break;
            }
        }
        // Sanity: we found a collision.
        assertTrue(wordB != bytes32(0), "should find bloom collision");
        assertTrue(wordA != wordB, "words must differ");

        ParseState memory state;
        state.lineTracker = 0;
        state.topLevel1 = 0;
        state.stackNames = 0;
        state.stackNameBloom = 0;

        // Push wordA only.
        LibParseStackName.pushStackName(state, wordA);
        state.lineTracker = 1;
        state.topLevel1 = 1;

        // Look up wordB — bloom hit (same bit) but fingerprint mismatch.
        (bool exists, uint256 index) = LibParseStackName.stackNameIndex(state, wordB);
        assertFalse(exists, "bloom false positive: should not exist");
        assertEq(index, 0, "bloom false positive: index should be 0");
    }

    /// Test that we can push and retrieve many stack names.
    function testPushAndRetrieveStackNameMany(ParseState memory state, uint256 n) external pure {
        n = bound(n, 1, 100);
        state.lineTracker = 0;
        state.topLevel1 = 0;
        state.stackNames = 0;

        // Do this sequentially to avoid dupes.
        for (uint256 i = 0; i < n; i++) {
            (bool exists, uint256 index) = LibParseStackName.pushStackName(state, bytes32(i));
            assertFalse(exists);
            assertEq(index, i + 1);
            state.lineTracker = index;
            state.topLevel1 = index;
        }

        for (uint256 i = 0; i < n; i++) {
            (bool exists, uint256 index) = LibParseStackName.stackNameIndex(state, bytes32(i));
            assertTrue(exists);
            assertEq(index, i);
        }
    }
}
