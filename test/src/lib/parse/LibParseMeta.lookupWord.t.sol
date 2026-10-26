// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {LibParseMeta} from "../../../../src/lib/parse/LibParseMeta.sol";
import {LibGenParseMeta} from "../../../../src/lib/codegen/LibGenParseMeta.sol";
import {LibAuthoringMeta, AuthoringMetaV2} from "test/lib/meta/LibAuthoringMeta.sol";
import {LibBloom} from "test/lib/bloom/LibBloom.sol";
import {LibParseMetaFingerprint} from "test/lib/meta/LibParseMetaFingerprint.sol";
import {
    META_ITEM_SIZE,
    FINGERPRINT_MASK,
    META_EXPANSION_SIZE,
    META_PREFIX_SIZE,
    InvalidParseMeta
} from "../../../../src/lib/parse/LibParseMeta.sol";

contract LibParseMetaLookupWordTest is Test {
    function checkParseMetaStructureExternal(bytes memory meta) external pure {
        LibParseMeta.checkParseMetaStructure(meta);
    }

    /// buildParseMetaV2 output must always pass structural validation.
    function testCheckParseMetaStructureBuildOutput() external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](3);
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        metas[0] = AuthoringMetaV2({word: bytes32("add"), description: ""});
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        metas[1] = AuthoringMetaV2({word: bytes32("sub"), description: ""});
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        metas[2] = AuthoringMetaV2({word: bytes32("mul"), description: ""});
        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 8);
        LibParseMeta.checkParseMetaStructure(meta);
    }

    /// Fuzz: any well-formed buildParseMetaV2 output passes validation.
    function testCheckParseMetaStructureFuzz(AuthoringMetaV2[] memory authoringMeta) external pure {
        vm.assume(authoringMeta.length > 0);
        vm.assume(authoringMeta.length <= 64);
        bytes32[] memory words = LibAuthoringMeta.copyWordsFromAuthoringMeta(authoringMeta);
        vm.assume(!LibBloom.bloomFindsDupes(words));
        // Two distinct words that share an expansion bit and a fingerprint cannot
        // both be represented in the parse meta, so generation rejects the set. See
        // `LibParseMetaFingerprint` for why that is correct rather than a defect.
        vm.assume(!LibParseMetaFingerprint.findsDupes(words));
        uint8 depth = uint8(authoringMeta.length / type(uint8).max + 3);
        bytes memory meta = LibGenParseMeta.buildParseMetaV2(authoringMeta, depth);
        LibParseMeta.checkParseMetaStructure(meta);
    }

    /// Truncated meta should fail validation.
    function testCheckParseMetaStructureTruncated() external {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](1);
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        metas[0] = AuthoringMetaV2({word: bytes32("add"), description: ""});
        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 8);

        // Truncate by 1 byte.
        bytes memory truncated = new bytes(meta.length - 1);
        for (uint256 i = 0; i < truncated.length; i++) {
            truncated[i] = meta[i];
        }
        vm.expectRevert(abi.encodeWithSelector(InvalidParseMeta.selector, meta.length, truncated.length));
        this.checkParseMetaStructureExternal(truncated);
    }

    /// Extra trailing bytes should fail validation.
    function testCheckParseMetaStructureExtraBytes() external {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](1);
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        metas[0] = AuthoringMetaV2({word: bytes32("add"), description: ""});
        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 8);

        // Append 1 extra byte.
        bytes memory extended = new bytes(meta.length + 1);
        for (uint256 i = 0; i < meta.length; i++) {
            extended[i] = meta[i];
        }
        vm.expectRevert(abi.encodeWithSelector(InvalidParseMeta.selector, meta.length, extended.length));
        this.checkParseMetaStructureExternal(extended);
    }

    /// Empty meta (zero length) should fail validation.
    function testCheckParseMetaStructureEmpty() external {
        bytes memory meta = new bytes(0);
        // depth=0, 0 expansions, 0 items → expected length = 1.
        vm.expectRevert(abi.encodeWithSelector(InvalidParseMeta.selector, META_PREFIX_SIZE, 0));
        this.checkParseMetaStructureExternal(meta);
    }

    /// Demonstrates M01: lookupWord does not check whether the word's bit is
    /// actually set in the bloom filter expansion before comparing fingerprints.
    /// We construct raw meta bytes where:
    /// - The expansion has a single bit set (NOT the lookup word's bit)
    /// - The item at position 0 has a fingerprint matching the lookup word
    /// This should return (false, 0) but currently returns (true, fakeIndex)
    /// because the bit-set check is missing.
    function testLookupWordMissingBitCheck() external pure {
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        bytes32 word = bytes32("notinmeta");
        uint8 seed = 0;

        // Compute word's bitmap and fingerprint, then build crafted meta.
        bytes memory meta = _buildM01Meta(word, seed);

        // lookupWord should return (false, 0) because the word's bit is NOT
        // set in the expansion. But due to M01, it returns (true, 42).
        (bool exists, uint256 index) = LibParseMeta.lookupWord(meta, word);
        assertFalse(exists, "M01: word bit not set in expansion, should not match");
        assertEq(index, 0, "M01: index should be 0 for not-found");
    }

    /// Fuzz variant of M01: any word should fail to match when its bit is not
    /// set in the expansion, regardless of fingerprint.
    function testLookupWordMissingBitCheckFuzz(bytes32 word, uint8 seed) external pure {
        bytes memory meta = _buildM01Meta(word, seed);

        (bool exists, uint256 index) = LibParseMeta.lookupWord(meta, word);
        assertFalse(exists, "M01 fuzz: word bit not set, should not match");
        assertEq(index, 0, "M01 fuzz: index should be 0 for not-found");
    }

    /// Constructs a crafted meta that triggers M01. The meta has one bloom
    /// layer with a single bit set that is NOT the lookup word's bit. The item
    /// at the position lookupWord will compute has a fingerprint matching the
    /// word. Without the bit-set check, lookupWord returns a false positive.
    function _buildM01Meta(bytes32 word, uint8 seed) internal pure returns (bytes memory meta) {
        (uint256 shifted, uint256 hashed) = LibParseMeta.wordBitmapped(seed, word);
        uint256 wordFingerprint = hashed & FINGERPRINT_MASK;

        // Find the word's bit position.
        uint256 bitPos;
        for (uint256 i = 0; i < 256; i++) {
            // Solidity << is value then shift amount, so 1 << n is the correct order.
            //forge-lint: disable-next-line(incorrect-shift)
            if (shifted == (1 << i)) {
                bitPos = i;
                break;
            }
        }

        // Pick a different bit ABOVE the word's bit so ctpop gives pos = 0.
        // Wrap around if needed — the key requirement is the bit differs.
        uint256 fakeBitPos = (bitPos + 128) % 256;
        // Solidity << is value then shift amount, so 1 << n is the correct order.
        //forge-lint: disable-next-line(incorrect-shift)
        uint256 fakeExpansion = 1 << fakeBitPos;

        // Determine what pos lookupWord will compute:
        // pos = ctpop(expansion & (shifted - 1))
        uint256 expectedPos = (fakeBitPos < bitPos) ? uint256(1) : uint256(0);

        uint256 numItems = expectedPos + 1;
        meta = new bytes(META_PREFIX_SIZE + META_EXPANSION_SIZE + numItems * META_ITEM_SIZE);

        // Write depth, seed, expansion.
        meta[0] = bytes1(uint8(1));
        meta[1] = bytes1(seed);
        for (uint256 i = 0; i < 32; i++) {
            meta[2 + i] = bytes1(uint8((fakeExpansion >> (8 * (31 - i))) & 0xFF));
        }

        // Write item at expectedPos with the word's fingerprint and a fake
        // opcode index of 42.
        uint256 itemOffset = META_PREFIX_SIZE + META_EXPANSION_SIZE + expectedPos * META_ITEM_SIZE;
        meta[itemOffset] = bytes1(uint8(42));
        meta[itemOffset + 1] = bytes1(uint8((wordFingerprint >> 16) & 0xFF));
        meta[itemOffset + 2] = bytes1(uint8((wordFingerprint >> 8) & 0xFF));
        // Masked to 8 bits before the cast, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        meta[itemOffset + 3] = bytes1(uint8(wordFingerprint & 0xFF));
    }

    /// Build meta from known words, look them all up, verify indices.
    function testLookupWordKnown() external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](3);
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        metas[0] = AuthoringMetaV2({word: bytes32("add"), description: ""});
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        metas[1] = AuthoringMetaV2({word: bytes32("sub"), description: ""});
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        metas[2] = AuthoringMetaV2({word: bytes32("mul"), description: ""});

        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 8);

        for (uint256 i = 0; i < metas.length; i++) {
            (bool exists, uint256 index) = LibParseMeta.lookupWord(meta, metas[i].word);
            assertTrue(exists, "word should exist");
            assertEq(index, i, "word index mismatch");
        }
    }

    /// Looking up a word not in meta should return false with index 0.
    function testLookupWordNotFound() external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](1);
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        metas[0] = AuthoringMetaV2({word: bytes32("add"), description: ""});

        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 8);

        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        (bool exists, uint256 index) = LibParseMeta.lookupWord(meta, bytes32("notaword"));
        assertFalse(exists);
        assertEq(index, 0);
    }

    /// Single-depth meta with a single word.
    function testLookupWordSingleDepth() external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](1);
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        metas[0] = AuthoringMetaV2({word: bytes32("only"), description: ""});

        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 1);

        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        (bool exists, uint256 index) = LibParseMeta.lookupWord(meta, bytes32("only"));
        assertTrue(exists);
        assertEq(index, 0);

        // Not-found on single-depth meta.
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        (bool notExists,) = LibParseMeta.lookupWord(meta, bytes32("other"));
        assertFalse(notExists);
    }

    /// Multiple not-found lookups should all return false.
    function testLookupWordMultipleNotFound(bytes32 a, bytes32 b, bytes32 c) external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](1);
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        metas[0] = AuthoringMetaV2({word: bytes32("known"), description: ""});

        // Ensure fuzzed words differ from the known word.
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        vm.assume(a != bytes32("known"));
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        vm.assume(b != bytes32("known"));
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        vm.assume(c != bytes32("known"));

        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 3);

        (bool existsA,) = LibParseMeta.lookupWord(meta, a);
        assertFalse(existsA);
        (bool existsB,) = LibParseMeta.lookupWord(meta, b);
        assertFalse(existsB);
        (bool existsC,) = LibParseMeta.lookupWord(meta, c);
        assertFalse(existsC);
    }

    /// Fuzz: every word in the authoring meta should be found at its correct
    /// index, and a random word not in the meta should not be found.
    function testLookupWordRoundtripFuzz(AuthoringMetaV2[] memory authoringMeta, bytes32 notFound) external pure {
        vm.assume(authoringMeta.length > 0);
        vm.assume(authoringMeta.length <= 64);
        bytes32[] memory words = LibAuthoringMeta.copyWordsFromAuthoringMeta(authoringMeta);
        vm.assume(!LibBloom.bloomFindsDupes(words));
        // Two distinct words that share an expansion bit and a fingerprint cannot
        // both be represented in the parse meta, so generation rejects the set. See
        // `LibParseMetaFingerprint` for why that is correct rather than a defect.
        vm.assume(!LibParseMetaFingerprint.findsDupes(words));
        for (uint256 i = 0; i < authoringMeta.length; i++) {
            vm.assume(authoringMeta[i].word != notFound);
        }

        uint8 depth = uint8(authoringMeta.length / type(uint8).max + 3);
        bytes memory meta = LibGenParseMeta.buildParseMetaV2(authoringMeta, depth);

        // Every word should be found at its index.
        for (uint256 i = 0; i < authoringMeta.length; i++) {
            (bool exists, uint256 index) = LibParseMeta.lookupWord(meta, authoringMeta[i].word);
            assertTrue(exists, "word should exist");
            assertEq(index, i, "index mismatch");
        }

        // A word not in meta should not be found.
        (bool notExists,) = LibParseMeta.lookupWord(meta, notFound);
        assertFalse(notExists, "unknown word should not exist");
    }

    /// Writes a 4-byte item (opcode index + 3 byte fingerprint) into `meta` at
    /// the item slot `itemIndex`, which is offset past the prefix byte and all
    /// `depth` expansion blocks.
    function _writeMetaItem(bytes memory meta, uint256 depth, uint256 itemIndex, uint8 opcodeIndex, uint256 fingerprint)
        internal
        pure
    {
        uint256 itemOffset = META_PREFIX_SIZE + depth * META_EXPANSION_SIZE + itemIndex * META_ITEM_SIZE;
        meta[itemOffset] = bytes1(opcodeIndex);
        meta[itemOffset + 1] = bytes1(uint8((fingerprint >> 16) & 0xFF));
        meta[itemOffset + 2] = bytes1(uint8((fingerprint >> 8) & 0xFF));
        // Masked to 8 bits before the cast, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        meta[itemOffset + 3] = bytes1(uint8(fingerprint & 0xFF));
    }

    /// Writes a depth byte, then for each of `depth` layers a seed byte
    /// immediately followed by its 32 byte expansion.
    function _writeMetaExpansions(bytes memory meta, uint8[] memory seeds, uint256[] memory expansions) internal pure {
        meta[0] = bytes1(uint8(seeds.length));
        for (uint256 d = 0; d < seeds.length; d++) {
            uint256 layerOffset = META_PREFIX_SIZE + d * META_EXPANSION_SIZE;
            meta[layerOffset] = bytes1(seeds[d]);
            for (uint256 i = 0; i < 32; i++) {
                meta[layerOffset + 1 + i] = bytes1(uint8((expansions[d] >> (8 * (31 - i))) & 0xFF));
            }
        }
    }

    /// A word whose bit is set at depth 0 but whose fingerprint does not match
    /// the item there must descend to the next bloom layer. The descent offsets
    /// the item index by the number of set bits in every prior expansion, so a
    /// match at depth 1 returns the item from the second layer's item block.
    ///
    /// Crafted meta with two layers, each holding a single set bit:
    /// - depth 0: the word's bit is set, but its item carries a foreign
    ///   fingerprint, so the fingerprint comparison fails.
    /// - depth 1: the word's bit is set, and its item carries the word's
    ///   fingerprint plus opcode index 7. lookupWord computes pos 0 within the
    ///   layer and adds cumulativeCt 1 (one bit set at depth 0), so it reads
    ///   item slot 1 and returns (true, 7).
    function testLookupWordCollisionDescent() external pure {
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        bytes32 word = bytes32("descend");
        bytes memory meta = new bytes(META_PREFIX_SIZE + 2 * META_EXPANSION_SIZE + 2 * META_ITEM_SIZE);

        {
            uint8[] memory seeds = new uint8[](2);
            seeds[0] = 1;
            seeds[1] = 2;
            uint256[] memory expansions = new uint256[](2);
            uint256 hashed0;
            uint256 hashed1;
            {
                uint256 shifted0;
                uint256 shifted1;
                (shifted0, hashed0) = LibParseMeta.wordBitmapped(seeds[0], word);
                (shifted1, hashed1) = LibParseMeta.wordBitmapped(seeds[1], word);
                // The seeds are chosen so the word lands on different bits per
                // layer; assert it so the crafted indices below hold.
                assertTrue(shifted0 != shifted1, "seeds must place word on distinct bits");
                // Each layer sets exactly the word's bit, so ctpop is 1 per
                // layer.
                expansions[0] = shifted0;
                expansions[1] = shifted1;
            }
            _writeMetaExpansions(meta, seeds, expansions);

            // Depth 0 item: a foreign fingerprint so the comparison fails.
            // Derived from the word's own fingerprint so it can never match.
            _writeMetaItem(meta, 2, 0, 99, ((hashed0 & FINGERPRINT_MASK) ^ 0x000001) & FINGERPRINT_MASK);
            // Depth 1 item: the word's fingerprint and the real opcode index 7.
            _writeMetaItem(meta, 2, 1, 7, hashed1 & FINGERPRINT_MASK);
        }

        // pos at depth 0 is 0; cumulativeCt becomes ctpop(expansion0) = 1 after
        // the fingerprint miss; pos at depth 1 is 0 + 1 = 1.
        (bool exists, uint256 index) = LibParseMeta.lookupWord(meta, word);
        assertTrue(exists, "word resolved after descending past the depth 0 miss");
        assertEq(index, 7, "index comes from the depth 1 item slot at offset 1");
    }

    /// A word whose bit is set at every depth but whose fingerprint never
    /// matches must miss once the loop runs past the last layer. The descent
    /// visits both layers and the post-loop return yields (false, 0).
    function testLookupWordDescendThenMiss() external pure {
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        bytes32 word = bytes32("nomatch");
        bytes memory meta = new bytes(META_PREFIX_SIZE + 2 * META_EXPANSION_SIZE + 2 * META_ITEM_SIZE);

        {
            uint8[] memory seeds = new uint8[](2);
            seeds[0] = 3;
            seeds[1] = 4;
            uint256[] memory expansions = new uint256[](2);
            uint256 hashed0;
            uint256 hashed1;
            {
                uint256 shifted0;
                uint256 shifted1;
                (shifted0, hashed0) = LibParseMeta.wordBitmapped(seeds[0], word);
                (shifted1, hashed1) = LibParseMeta.wordBitmapped(seeds[1], word);
                expansions[0] = shifted0;
                expansions[1] = shifted1;
            }
            _writeMetaExpansions(meta, seeds, expansions);

            // Both item slots carry foreign fingerprints, so neither matches.
            _writeMetaItem(meta, 2, 0, 11, ((hashed0 & FINGERPRINT_MASK) ^ 0x000001) & FINGERPRINT_MASK);
            _writeMetaItem(meta, 2, 1, 22, ((hashed1 & FINGERPRINT_MASK) ^ 0x000001) & FINGERPRINT_MASK);
        }

        (bool exists, uint256 index) = LibParseMeta.lookupWord(meta, word);
        assertFalse(exists, "bit set at every depth but no fingerprint matched");
        assertEq(index, 0, "miss returns index 0");
    }

    /// Larger word set forcing multi-depth bloom — verify all words still
    /// resolve correctly.
    function testLookupWordLargeSet() external pure {
        uint256 count = 50;
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](count);
        for (uint256 i = 0; i < count; i++) {
            metas[i] = AuthoringMetaV2({word: bytes32(i + 1), description: ""});
        }

        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 5);

        for (uint256 i = 0; i < count; i++) {
            (bool exists, uint256 index) = LibParseMeta.lookupWord(meta, bytes32(i + 1));
            assertTrue(exists, "word should exist");
            assertEq(index, i, "index mismatch");
        }

        // Zero was not added.
        (bool notExists,) = LibParseMeta.lookupWord(meta, bytes32(uint256(0)));
        assertFalse(notExists);
    }
}
