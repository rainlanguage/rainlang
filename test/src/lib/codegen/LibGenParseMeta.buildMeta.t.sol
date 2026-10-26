// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";

import {LibParseMeta} from "../../../../src/lib/parse/LibParseMeta.sol";
import {LibAuthoringMeta, AuthoringMetaV2} from "test/lib/meta/LibAuthoringMeta.sol";
import {
    LibGenParseMeta,
    DuplicateFingerprint,
    AuthoringMetaTooLarge,
    MaxDepthExceeded,
    META_ITEM_MASK
} from "../../../../src/lib/codegen/LibGenParseMeta.sol";
import {META_ITEM_SIZE} from "../../../../src/lib/parse/LibParseMeta.sol";
import {LibBloom} from "test/lib/bloom/LibBloom.sol";
import {LibParseMetaFingerprint} from "test/lib/meta/LibParseMetaFingerprint.sol";

contract LibGenParseMetaBuildMetaTest is Test {
    /// META_ITEM_MASK must be a full META_ITEM_SIZE-byte mask (32 bits for
    /// 4-byte items). Previously the constant was (1 << 4) - 1 = 0xF which
    /// is only 4 bits.
    function testMetaItemMask() external pure {
        // Solidity << is value then shift amount, so 1 << n is the correct order.
        //forge-lint: disable-next-line(incorrect-shift)
        assertEq(META_ITEM_MASK, (1 << (META_ITEM_SIZE * 8)) - 1);
        assertEq(META_ITEM_MASK, type(uint32).max);
    }

    /// Zero words should produce a 1-byte meta (just the depth prefix = 0).
    function testBuildParseMetaV2ZeroWords() external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](0);
        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 8);
        assertEq(meta.length, 1);
        assertEq(uint8(meta[0]), 0);
    }

    function buildParseMetaV2External(AuthoringMetaV2[] memory authoringMeta, uint8 maxDepth)
        external
        pure
        returns (bytes memory)
    {
        return LibGenParseMeta.buildParseMetaV2(authoringMeta, maxDepth);
    }

    /// This is super loose from limited empirical testing.
    function expanderDepth(uint256 n) internal pure returns (uint8) {
        // Number of fully saturated expanders
        // + 1 for solidity flooring everything
        // + 1 for a non-fully saturated but still quite full expander
        // + 1 for a potentially nearly empty expander
        // This is NOT a safe typecast, but in normal useage we are unlikely to
        // get anywhere near the limit as that would imply ~256^2 words.
        //forge-lint: disable-next-line(unsafe-typecast)
        return uint8(n / type(uint8).max + 3);
    }

    function testBuildMeta(AuthoringMetaV2[] memory authoringMeta) external pure {
        bytes32[] memory words = LibAuthoringMeta.copyWordsFromAuthoringMeta(authoringMeta);
        vm.assume(!LibBloom.bloomFindsDupes(words));
        // Two distinct words that share an expansion bit and a fingerprint cannot
        // both be represented in the parse meta, so generation rejects the set. See
        // `LibParseMetaFingerprint` for why that is correct rather than a defect.
        vm.assume(!LibParseMetaFingerprint.findsDupes(words));
        bytes memory meta = LibGenParseMeta.buildParseMetaV2(authoringMeta, expanderDepth(authoringMeta.length));
        (meta);
    }

    function testRoundMetaExpanderShallow(AuthoringMetaV2[] memory authoringMeta, uint8 j, bytes32 notFound)
        external
        pure
    {
        vm.assume(authoringMeta.length > 0);
        bytes32[] memory words = LibAuthoringMeta.copyWordsFromAuthoringMeta(authoringMeta);
        vm.assume(!LibBloom.bloomFindsDupes(words));
        // Two distinct words that share an expansion bit and a fingerprint cannot
        // both be represented in the parse meta, so generation rejects the set. See
        // `LibParseMetaFingerprint` for why that is correct rather than a defect.
        vm.assume(!LibParseMetaFingerprint.findsDupes(words));
        for (uint256 i = 0; i < authoringMeta.length; i++) {
            vm.assume(authoringMeta[i].word != notFound);
        }
        j = uint8(bound(j, uint8(0), uint8(authoringMeta.length) - 1));

        bytes memory meta = LibGenParseMeta.buildParseMetaV2(authoringMeta, expanderDepth(authoringMeta.length));
        (bool exists, uint256 k) = LibParseMeta.lookupWord(meta, authoringMeta[j].word);
        assertTrue(exists, "exists");
        assertEq(j, k, "k");

        (bool notExists, uint256 l) = LibParseMeta.lookupWord(meta, notFound);
        assertTrue(!notExists, "notExists");
        assertEq(0, l, "l");
    }

    function testRoundMetaExpanderDeeper(AuthoringMetaV2[] memory authoringMeta, uint8 j, bytes32 notFound)
        external
        pure
    {
        vm.assume(authoringMeta.length > 50);
        bytes32[] memory words = LibAuthoringMeta.copyWordsFromAuthoringMeta(authoringMeta);
        vm.assume(!LibBloom.bloomFindsDupes(words));
        // Two distinct words that share an expansion bit and a fingerprint cannot
        // both be represented in the parse meta, so generation rejects the set. See
        // `LibParseMetaFingerprint` for why that is correct rather than a defect.
        vm.assume(!LibParseMetaFingerprint.findsDupes(words));
        for (uint256 i = 0; i < authoringMeta.length; i++) {
            vm.assume(authoringMeta[i].word != notFound);
        }
        j = uint8(bound(j, uint8(0), uint8(authoringMeta.length) - 1));

        bytes memory meta = LibGenParseMeta.buildParseMetaV2(authoringMeta, expanderDepth(authoringMeta.length));

        (bool exists, uint256 k) = LibParseMeta.lookupWord(meta, authoringMeta[j].word);
        assertTrue(exists, "exists");
        assertEq(j, k, "k");

        (bool notExists, uint256 l) = LibParseMeta.lookupWord(meta, notFound);
        assertTrue(!notExists, "notExists");
        assertEq(0, l, "l");
    }

    function testBuildMetaDuplicateFingerprint() external {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](2);
        metas[0] = AuthoringMetaV2({word: bytes32(uint256(1)), description: "a"});
        metas[1] = AuthoringMetaV2({word: bytes32(uint256(1)), description: "b"});

        vm.expectRevert(abi.encodeWithSelector(DuplicateFingerprint.selector));
        this.buildParseMetaV2External(metas, 3);
    }

    /// 257 words should revert with AuthoringMetaTooLarge.
    function testBuildMetaTooLarge257() external {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](257);
        for (uint256 i = 0; i < 257; i++) {
            metas[i] = AuthoringMetaV2({word: bytes32(i), description: ""});
        }
        vm.expectRevert(abi.encodeWithSelector(AuthoringMetaTooLarge.selector, 257));
        this.buildParseMetaV2External(metas, 8);
    }

    /// Fuzz: any length above 256 should revert with AuthoringMetaTooLarge.
    function testBuildMetaTooLargeFuzz(uint256 length) external {
        length = bound(length, 257, 512);
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](length);
        for (uint256 i = 0; i < length; i++) {
            metas[i] = AuthoringMetaV2({word: bytes32(i), description: ""});
        }
        vm.expectRevert(abi.encodeWithSelector(AuthoringMetaTooLarge.selector, length));
        this.buildParseMetaV2External(metas, 8);
    }

    /// maxDepth=1 with enough words to force multiple bloom layers should
    /// revert with MaxDepthExceeded.
    function testBuildMetaMaxDepthExceeded() external {
        // 256 unique words will need more than 1 bloom layer.
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](256);
        for (uint256 i = 0; i < 256; i++) {
            metas[i] = AuthoringMetaV2({word: bytes32(i), description: ""});
        }
        vm.expectRevert(abi.encodeWithSelector(MaxDepthExceeded.selector, 1));
        this.buildParseMetaV2External(metas, 1);
    }

    /// Fuzz: maxDepth=1 with more than 1 word that collides should revert.
    /// Even 2 words can collide at depth 1 if they share a bit position for
    /// every seed — but with 256+ words, collision is guaranteed.
    function testBuildMetaMaxDepthExceededFuzz(uint8 maxDepth) external {
        // Use enough words that the required depth exceeds maxDepth.
        // 256 words need at least 2 layers; bound maxDepth to 1.
        vm.assume(maxDepth < 2);
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](256);
        for (uint256 i = 0; i < 256; i++) {
            metas[i] = AuthoringMetaV2({word: bytes32(i), description: ""});
        }
        vm.expectRevert(abi.encodeWithSelector(MaxDepthExceeded.selector, maxDepth));
        this.buildParseMetaV2External(metas, maxDepth);
    }

    /// Exactly 256 words should succeed (boundary).
    function testBuildMeta256Words() external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](256);
        for (uint256 i = 0; i < 256; i++) {
            metas[i] = AuthoringMetaV2({word: bytes32(i), description: ""});
        }
        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 8);
        assertTrue(meta.length > 0);
    }

    /// The generated parse meta from parseMetaConstantString should be
    /// functionally equivalent to calling buildParseMetaV2 directly. Verify
    /// by building both ways and checking all words can be looked up with
    /// correct indices.
    function testParseMetaConstantStringRoundtrip() external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](3);
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        metas[0] = AuthoringMetaV2({word: bytes32("add"), description: "Add two numbers"});
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        metas[1] = AuthoringMetaV2({word: bytes32("sub"), description: "Subtract"});
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        metas[2] = AuthoringMetaV2({word: bytes32("mul"), description: "Multiply"});

        bytes memory encoded = abi.encode(metas);
        string memory result = LibGenParseMeta.parseMetaConstantString(vm, encoded, 3);

        // The function should produce non-empty output.
        assertTrue(bytes(result).length > 0);

        // Verify the underlying parse meta is functional by building it
        // directly and checking all words resolve.
        bytes memory parseMeta = LibGenParseMeta.buildParseMetaV2(metas, 3);
        for (uint256 i = 0; i < metas.length; i++) {
            (bool exists, uint256 index) = LibParseMeta.lookupWord(parseMeta, metas[i].word);
            assertTrue(exists, "word should exist");
            assertEq(index, i, "word index mismatch");
        }
    }

    /// Empty authoring meta should produce a valid (non-empty) constant string.
    function testParseMetaConstantStringEmpty() external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](0);
        bytes memory encoded = abi.encode(metas);
        string memory result = LibGenParseMeta.parseMetaConstantString(vm, encoded, 1);

        assertTrue(bytes(result).length > 0);
    }

    /// Single word should produce a valid constant string and the parse meta
    /// built internally should correctly look up that word.
    function testParseMetaConstantStringSingleWord() external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](1);
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        metas[0] = AuthoringMetaV2({word: bytes32("only"), description: "The only word"});

        bytes memory encoded = abi.encode(metas);
        string memory result = LibGenParseMeta.parseMetaConstantString(vm, encoded, 1);

        assertTrue(bytes(result).length > 0);

        bytes memory parseMeta = LibGenParseMeta.buildParseMetaV2(metas, 1);
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        (bool exists, uint256 index) = LibParseMeta.lookupWord(parseMeta, bytes32("only"));
        assertTrue(exists);
        assertEq(index, 0);
    }

    /// Different build depths should all produce valid output for the same
    /// input, and the underlying parse meta should remain functional.
    function testParseMetaConstantStringBuildDepths() external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](2);
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        metas[0] = AuthoringMetaV2({word: bytes32("foo"), description: ""});
        // Casting a string literal that fits in 32 bytes, so it cannot truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        metas[1] = AuthoringMetaV2({word: bytes32("bar"), description: ""});

        bytes memory encoded = abi.encode(metas);

        for (uint8 depth = 1; depth <= 5; depth++) {
            string memory result = LibGenParseMeta.parseMetaConstantString(vm, encoded, depth);
            assertTrue(bytes(result).length > 0);

            bytes memory parseMeta = LibGenParseMeta.buildParseMetaV2(metas, depth);
            for (uint256 i = 0; i < metas.length; i++) {
                (bool exists, uint256 index) = LibParseMeta.lookupWord(parseMeta, metas[i].word);
                assertTrue(exists);
                assertEq(index, i);
            }
        }
    }

    /// Fuzz: parseMetaConstantString should not revert for any valid
    /// (no duplicate words) authoring meta.
    function testParseMetaConstantStringFuzz(AuthoringMetaV2[] memory authoringMeta) external pure {
        bytes32[] memory words = LibAuthoringMeta.copyWordsFromAuthoringMeta(authoringMeta);
        vm.assume(!LibBloom.bloomFindsDupes(words));
        // Two distinct words that share an expansion bit and a fingerprint cannot
        // both be represented in the parse meta, so generation rejects the set. See
        // `LibParseMetaFingerprint` for why that is correct rather than a defect.
        vm.assume(!LibParseMetaFingerprint.findsDupes(words));
        bytes memory encoded = abi.encode(authoringMeta);
        string memory result = LibGenParseMeta.parseMetaConstantString(vm, encoded, expanderDepth(authoringMeta.length));
        assertTrue(bytes(result).length > 0);
    }
}
