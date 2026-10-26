// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";

import {FINGERPRINT_MASK, LibParseMeta} from "../../../src/lib/parse/LibParseMeta.sol";
import {LibParseMetaFingerprint} from "test/lib/meta/LibParseMetaFingerprint.sol";

/// @title LibParseMetaFingerprintTest
/// @notice `LibParseMetaFingerprint.findsDupes` is the guard the parse meta
/// fuzz tests use to drop word sets that `buildParseMetaV2` cannot represent.
/// A guard that never flags anything would let the flake back in and a guard
/// that always flags would starve the fuzz tests, so both directions are
/// pinned here.
contract LibParseMetaFingerprintTest is Test {
    /// @dev First word of the colliding pair from the fuzz counterexample in
    /// `rainix-sol / test` run 36937526403. See
    /// `LibGenParseMeta.duplicateFingerprint.t.sol` for the full word set.
    bytes32 internal constant COLLIDING_WORD_A = 0x86e6c750812268cb7a787a9a61914291a7c4b826dec7121ce18513e36360548c;

    /// @dev Second word of that pair.
    bytes32 internal constant COLLIDING_WORD_B = 0x25ef4d0911347dbb91e5246ed252343ffa319f560604eef7ae52b89555e8088c;

    /// @dev The only seed in `[0, 255]` under which the pair collides.
    uint256 internal constant COLLIDING_SEED = 59;

    /// Nothing to collide with.
    function testFindsDupesEmpty() external pure {
        assertFalse(LibParseMetaFingerprint.findsDupes(new bytes32[](0)));
    }

    /// A single word cannot collide with anything, for any word.
    function testFindsDupesSingleFuzz(bytes32 word) external pure {
        bytes32[] memory words = new bytes32[](1);
        words[0] = word;
        assertFalse(LibParseMetaFingerprint.findsDupes(words));
    }

    /// A repeated word always collides with itself: same bit, same
    /// fingerprint, under every seed.
    function testFindsDupesRepeatedWordFuzz(bytes32 word, uint8 count) external pure {
        uint256 length = bound(count, 2, 8);
        bytes32[] memory words = new bytes32[](length);
        for (uint256 i = 0; i < length; i++) {
            words[i] = word;
        }
        assertTrue(LibParseMetaFingerprint.findsDupes(words));
    }

    /// A repeated word is found wherever the repeat sits, not only adjacent to
    /// its first occurrence.
    function testFindsDupesNonAdjacentRepeat() external pure {
        bytes32[] memory words = new bytes32[](4);
        // Casting string literals that fit in 32 bytes, so they cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        words[0] = bytes32("add");
        //forge-lint: disable-next-line(unsafe-typecast)
        words[1] = bytes32("sub");
        //forge-lint: disable-next-line(unsafe-typecast)
        words[2] = bytes32("mul");
        //forge-lint: disable-next-line(unsafe-typecast)
        words[3] = bytes32("add");
        assertTrue(LibParseMetaFingerprint.findsDupes(words));
    }

    /// A real, representable word set must pass the guard, otherwise the fuzz
    /// tests it guards would never reach their assertions.
    function testFindsDupesCleanSet() external pure {
        bytes32[] memory words = new bytes32[](4);
        // Casting string literals that fit in 32 bytes, so they cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        words[0] = bytes32("add");
        //forge-lint: disable-next-line(unsafe-typecast)
        words[1] = bytes32("sub");
        //forge-lint: disable-next-line(unsafe-typecast)
        words[2] = bytes32("mul");
        //forge-lint: disable-next-line(unsafe-typecast)
        words[3] = bytes32("div");
        assertFalse(LibParseMetaFingerprint.findsDupes(words));
    }

    /// Sequential words are representable, so a long run of them must pass.
    /// A guard that flagged these would silently gut the large-set fuzz tests.
    function testFindsDupesSequentialWords() external pure {
        bytes32[] memory words = new bytes32[](128);
        for (uint256 i = 0; i < words.length; i++) {
            words[i] = bytes32(i + 1);
        }
        assertFalse(LibParseMetaFingerprint.findsDupes(words));
    }

    /// The guard must scan every seed, not just the first. This pair is
    /// distinguishable under seed 0 and collides only under seed 59, so a
    /// guard that stopped at seed 0 would miss it — and that is exactly the
    /// collision that flaked CI.
    function testFindsDupesCollisionOnlyAtNonZeroSeed() external pure {
        (uint256 bitmapA, uint256 hashedA) = LibParseMeta.wordBitmapped(0, COLLIDING_WORD_A);
        (uint256 bitmapB, uint256 hashedB) = LibParseMeta.wordBitmapped(0, COLLIDING_WORD_B);
        assertTrue(
            bitmapA != bitmapB || (hashedA & FINGERPRINT_MASK) != (hashedB & FINGERPRINT_MASK),
            "pair is representable under seed 0"
        );

        (bitmapA, hashedA) = LibParseMeta.wordBitmapped(COLLIDING_SEED, COLLIDING_WORD_A);
        (bitmapB, hashedB) = LibParseMeta.wordBitmapped(COLLIDING_SEED, COLLIDING_WORD_B);
        assertEq(bitmapA, bitmapB, "same expansion bit under the colliding seed");
        assertEq(hashedA & FINGERPRINT_MASK, hashedB & FINGERPRINT_MASK, "same fingerprint");

        bytes32[] memory words = new bytes32[](2);
        words[0] = COLLIDING_WORD_A;
        words[1] = COLLIDING_WORD_B;
        assertTrue(LibParseMetaFingerprint.findsDupes(words), "guard must scan every seed");

        // Order must not matter.
        words[0] = COLLIDING_WORD_B;
        words[1] = COLLIDING_WORD_A;
        assertTrue(LibParseMetaFingerprint.findsDupes(words), "guard is order independent");
    }

    /// The colliding pair must still be found when it is buried in a larger
    /// set. The fillers here are sequential words, so whether any of them
    /// shares the pair's bucket is a property of their hashes rather than of
    /// this test; `testFindsDupesCollisionBehindAChainHead` is the one that
    /// pins chain walking.
    function testFindsDupesCollisionBuriedInSet() external pure {
        bytes32[] memory words = new bytes32[](64);
        words[0] = COLLIDING_WORD_A;
        for (uint256 i = 1; i < words.length - 1; i++) {
            words[i] = bytes32(i);
        }
        words[words.length - 1] = COLLIDING_WORD_B;
        assertTrue(LibParseMetaFingerprint.findsDupes(words));
    }

    /// A collision sitting behind another word in the same chain must still be
    /// found. The filler is chosen to share `COLLIDING_WORD_A`'s bucket under
    /// the colliding seed, so it is the chain head when `COLLIDING_WORD_B`
    /// arrives and the pair is only reachable by walking past it.
    function testFindsDupesCollisionBehindAChainHead() external pure {
        (, uint256 hashedA) = LibParseMeta.wordBitmapped(COLLIDING_SEED, COLLIDING_WORD_A);
        uint256 fingerprintA = hashedA & FINGERPRINT_MASK;

        bytes32 filler;
        uint256 fingerprintFiller;
        for (uint256 i = 1; i < 0x400; i++) {
            (, uint256 hashed) = LibParseMeta.wordBitmapped(COLLIDING_SEED, bytes32(i));
            uint256 fingerprint = hashed & FINGERPRINT_MASK;
            if (fingerprint & 0xFF == fingerprintA & 0xFF) {
                filler = bytes32(i);
                fingerprintFiller = fingerprint;
                break;
            }
        }
        assertTrue(filler != bytes32(0), "no filler shares the bucket");
        // A filler that collided outright would be found without walking.
        assertTrue(fingerprintFiller != fingerprintA, "filler collides with the pair");

        bytes32[] memory words = new bytes32[](3);
        words[0] = COLLIDING_WORD_A;
        words[1] = filler;
        words[2] = COLLIDING_WORD_B;
        assertTrue(LibParseMetaFingerprint.findsDupes(words), "pair behind a chain head");
    }
}
