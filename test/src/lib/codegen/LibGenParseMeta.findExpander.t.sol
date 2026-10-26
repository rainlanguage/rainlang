//// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";

import {LibBloom} from "test/lib/bloom/LibBloom.sol";
import {LibCtPop} from "rain-math-binary-0.1.4/src/lib/LibCtPop.sol";
import {LibAuthoringMeta, AuthoringMetaV2} from "test/lib/meta/LibAuthoringMeta.sol";
import {LibGenParseMeta} from "../../../../src/lib/codegen/LibGenParseMeta.sol";
import {LibGenParseMetaSlow} from "test/src/lib/codegen/LibGenParseMetaSlow.sol";

/// @title LibGenParseMetaFindExpanderTest
/// Test that we can find reasonable expansions in a reasonable number of
/// iterations for a reasonable number of words.
contract LibGenParseMetaFindExpanderTest is Test {
    function buildAuthoringMeta(AuthoringMetaV2[0x20] memory source, uint256 length)
        internal
        pure
        returns (AuthoringMetaV2[] memory)
    {
        AuthoringMetaV2[] memory authoringMeta = new AuthoringMetaV2[](length);
        for (uint256 i = 0; i < length; i++) {
            authoringMeta[i] = source[i];
        }
        return authoringMeta;
    }

    /// Test that we can find an expansion for a small number of words in a
    /// single iteration.
    /// Birthday paradox says we should expect to find a collision in 256 slots
    /// and 32 words 86.76% of the time.
    /// https://www.wolframalpha.com/input?i=birthday+problem+calculator&assumption=%7B%22F%22%2C+%22BirthdayProblem%22%2C+%22pbds%22%7D+-%3E%22256%22&assumption=%7B%22F%22%2C+%22BirthdayProblem%22%2C+%22n%22%7D+-%3E%2232%22&assumption=%22FSelect%22+-%3E+%7B%7B%22BirthdayProblem%22%7D%7D
    /// The probability of finding a collision in EVERY iteration is 0.8676^256
    /// which is 1.621075e-16. I.e. we shoud expect the fuzz test to basically
    /// never fail for ~1000 runs.
    function testFindExpanderSmall(AuthoringMetaV2[0x20] memory source, uint256 length) external pure {
        AuthoringMetaV2[] memory authoringMeta = buildAuthoringMeta(source, bound(length, 0, 0x20));
        vm.assume(!LibBloom.bloomFindsDupes(LibAuthoringMeta.copyWordsFromAuthoringMeta(authoringMeta)));

        (uint8 seed, uint256 expansion, AuthoringMetaV2[] memory remaining) =
            LibGenParseMeta.findBestExpander(authoringMeta);
        (seed);
        assertEq(LibCtPop.ctpop(expansion), authoringMeta.length);
        assertEq(remaining.length, 0);
    }

    /// Empty input should return bestSeed 0, empty expansion, empty remaining.
    function testFindExpanderEmpty() external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](0);
        (uint8 bestSeed, uint256 bestExpansion, AuthoringMetaV2[] memory remaining) =
            LibGenParseMeta.findBestExpander(metas);
        assertEq(bestSeed, 0);
        assertEq(bestExpansion, 0);
        assertEq(remaining.length, 0);
    }

    /// Large input (64 elements) forces non-empty remaining array due to
    /// bloom filter collisions.
    function testFindExpanderLarge() external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](64);
        for (uint256 i = 0; i < 64; i++) {
            metas[i] = AuthoringMetaV2({word: bytes32(i), description: ""});
        }
        (, uint256 bestExpansion, AuthoringMetaV2[] memory remaining) = LibGenParseMeta.findBestExpander(metas);
        uint256 expandedCount = LibCtPop.ctpop(bestExpansion);
        assertEq(remaining.length, 64 - expandedCount);
    }

    /// Single word should always get a perfect expansion with no remaining.
    function testFindExpanderSingleWord(bytes32 word) external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](1);
        metas[0] = AuthoringMetaV2({word: word, description: ""});
        (, uint256 bestExpansion, AuthoringMetaV2[] memory remaining) = LibGenParseMeta.findBestExpander(metas);
        assertEq(LibCtPop.ctpop(bestExpansion), 1);
        assertEq(remaining.length, 0);
    }

    /// Fuzz: the invariant expandedCount + remaining.length == metas.length
    /// must always hold.
    function testFindExpanderInvariant(AuthoringMetaV2[] memory authoringMeta) external pure {
        vm.assume(!LibBloom.bloomFindsDupes(LibAuthoringMeta.copyWordsFromAuthoringMeta(authoringMeta)));
        (, uint256 bestExpansion, AuthoringMetaV2[] memory remaining) = LibGenParseMeta.findBestExpander(authoringMeta);
        uint256 expandedCount = LibCtPop.ctpop(bestExpansion);
        assertEq(expandedCount + remaining.length, authoringMeta.length);
    }

    /// Fuzz: findBestExpander must agree with the reference implementation
    /// that searches all 256 seeds.
    function testFindExpanderMatchesReference(AuthoringMetaV2[0x20] memory source, uint256 length) external pure {
        AuthoringMetaV2[] memory authoringMeta = buildAuthoringMeta(source, bound(length, 1, 0x20));
        vm.assume(!LibBloom.bloomFindsDupes(LibAuthoringMeta.copyWordsFromAuthoringMeta(authoringMeta)));

        (uint8 refBestSeed, uint256 refBestCt) = LibGenParseMetaSlow.findBestExpanderSlow(authoringMeta);

        (uint8 bestSeed, uint256 bestExpansion,) = LibGenParseMeta.findBestExpander(authoringMeta);
        assertEq(bestSeed, refBestSeed, "seed mismatch");
        assertEq(LibCtPop.ctpop(bestExpansion), refBestCt, "expansion count mismatch");
    }
}
