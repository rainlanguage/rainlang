// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";

import {LibBloom} from "test/lib/bloom/LibBloom.sol";

/// @title LibBloomTest
/// @notice This is a test contract for LibBloom. LibBloom itself is only used
/// for testing currently, but if it is buggy it undermines a lot of the rest
/// of the test suite.
contract LibBloomTest is Test {
    /// A bloom filter should never return false negatives, even though it
    /// typically has a high false positive rate.
    function testLibBloomNoFalseNegatives(bytes32[] memory words, uint256 a, uint256 b) external pure {
        vm.assume(words.length > 1);
        /// Copy a random work to another random word to force a dupe.
        uint256 j = a % words.length;
        uint256 k = b % words.length;
        vm.assume(j != k);
        words[k] = words[j];

        assertTrue(LibBloom.bloomFindsDupes(words));
    }

    /// The most attempts the search below is allowed to make before it declares
    /// the filter saturated. At the longest length tested roughly 1 draw in 22
    /// is dupe free, so exhausting this many independent draws on a working
    /// filter has odds around 1e-11, while the worst case costs about a fifth of
    /// the gas available to a test.
    uint256 internal constant ATTEMPTS = 512;

    /// With random words the chance of false positives is much higher. Described
    /// by the birthday paradox. A dupe free draw exists at every length tested,
    /// so a bounded search over independent draws finds one.
    ///
    /// Each attempt must be an independent draw. Deriving the next attempt by
    /// sliding a window of sequential values along by one leaves all but one
    /// word shared with the previous attempt, which correlates the outcomes so
    /// heavily that the search runs for thousands of attempts. Mixing the
    /// attempt counter into the seed replaces every word each time.
    function testLibBloomVaguelyAvoidsFalsePositives(uint256 start, uint8 len) external pure {
        // The ability for the bloom filter to avoid saturation starts to max out
        // around 180 words. This is a very loose bound.
        len = uint8(bound(len, 0, 180));
        // Allocated once and overwritten in place by every attempt. Allocating
        // per attempt abandons the previous array, so memory grows with the
        // attempt count and the gas cost of expanding it grows quadratically.
        bytes32[] memory words = new bytes32[](len);
        bool dupeFreeFound = false;
        for (uint256 attempt = 0; attempt < ATTEMPTS && !dupeFreeFound; attempt++) {
            bytes32 seed = keccak256(abi.encodePacked(start, attempt));
            for (uint256 i = 0; i < len; i++) {
                // Do a keccak256 here to avoid the trivial case of the bloom filter
                // just mapping every sequential value to a bit in the filter.
                words[i] = keccak256(abi.encodePacked(seed, i));
            }
            dupeFreeFound = !LibBloom.bloomFindsDupes(words);
        }
        assertTrue(dupeFreeFound, "bloom filter saturated: no dupe free draw");
    }
}
