// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {FINGERPRINT_MASK, LibParseMeta} from "../../../src/lib/parse/LibParseMeta.sol";

/// @title LibParseMetaFingerprint
/// @notice Fuzz input guard for parse meta generation.
///
/// `LibGenParseMeta.buildParseMetaV2` reverts with `DuplicateFingerprint` when
/// two words map to the same expansion bit AND carry the same 3 byte
/// fingerprint under one of the seeds it picks. The two words are then
/// indistinguishable in the 4 byte meta item, so the meta cannot represent both
/// and generation has to fail. That is a documented and intended outcome of a
/// 1 byte bitmap plus 3 byte fingerprint address space, which gives the same
/// collision resistance as a solidity selector. A real word set that hits it is
/// fixed by renaming a word, not by changing the library.
///
/// A fuzzer drawing uniformly random `bytes32` words draws that ~2^-32 per pair
/// coincidence often enough to flake CI, so fuzz tests that build a parse meta
/// from a fuzzed word set must exclude such sets up front rather than assert
/// that generation succeeds for them.
library LibParseMetaFingerprint {
    /// Returns true if any two words in `words` share both the expansion bit
    /// and the 3 byte fingerprint under ANY seed in `[0, type(uint8).max]`.
    ///
    /// `buildParseMetaV2` only uses the handful of seeds `findBestExpander`
    /// picks, so scanning every seed is deliberately conservative: the word
    /// sets flagged here are a strict superset of the ones that actually
    /// revert. A `false` result therefore guarantees `buildParseMetaV2` cannot
    /// revert with `DuplicateFingerprint` for `words`. The over-rejection is a
    /// ~256x multiple of a ~2^-32 per pair event, so it costs a negligible
    /// fraction of fuzz runs.
    ///
    /// This is exact rather than bloomed — there are no false positives from
    /// the detection itself. Words are chained on the low fingerprint byte so
    /// that only words that could possibly collide are compared, and those are
    /// compared on the full fingerprint and the full bitmap.
    /// @param words The words to check for an unrepresentable pair.
    /// @return True if some pair of words collides under some seed.
    function findsDupes(bytes32[] memory words) internal pure returns (bool) {
        unchecked {
            uint256 length = words.length;
            // A single word cannot collide with anything.
            if (length < 2) {
                return false;
            }

            // Expansion bitmap and fingerprint per word, recomputed per seed.
            uint256[] memory bitmaps = new uint256[](length);
            uint256[] memory fingerprints = new uint256[](length);
            // 1 based index of the first word chained to each bucket, 0 for an
            // empty bucket. Cleared at the end of each seed so that the single
            // allocation is reused.
            uint256[] memory head = new uint256[](0x100);
            // 1 based index of the next word in the same bucket, 0 for the end
            // of a chain.
            uint256[] memory next = new uint256[](length);

            for (uint256 seed = 0; seed <= type(uint8).max; seed++) {
                for (uint256 i = 0; i < length; i++) {
                    (uint256 bitmap, uint256 hashed) = LibParseMeta.wordBitmapped(seed, words[i]);
                    uint256 fingerprint = hashed & FINGERPRINT_MASK;
                    bitmaps[i] = bitmap;
                    fingerprints[i] = fingerprint;

                    // Bucketing on the low fingerprint byte only has to be
                    // consistent, not meaningful — a colliding pair agrees on
                    // the whole fingerprint, so it always lands in the same
                    // bucket and is always compared.
                    uint256 bucket = fingerprint & 0xFF;
                    for (uint256 cursor = head[bucket]; cursor > 0; cursor = next[cursor - 1]) {
                        if (fingerprints[cursor - 1] == fingerprint && bitmaps[cursor - 1] == bitmap) {
                            return true;
                        }
                    }
                    next[i] = head[bucket];
                    head[bucket] = i + 1;
                }

                // Clear only the buckets this seed touched.
                for (uint256 i = 0; i < length; i++) {
                    head[fingerprints[i] & 0xFF] = 0;
                }
            }
            return false;
        }
    }
}
