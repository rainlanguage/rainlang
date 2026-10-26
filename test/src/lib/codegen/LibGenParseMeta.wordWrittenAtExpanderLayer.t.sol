// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";

import {AuthoringMetaV2} from "../../../../src/interface/IParserV2.sol";
import {
    FINGERPRINT_MASK,
    META_EXPANSION_SIZE,
    META_ITEM_SIZE,
    META_PREFIX_SIZE,
    LibParseMeta
} from "../../../../src/lib/parse/LibParseMeta.sol";
import {LibGenParseMeta} from "../../../../src/lib/codegen/LibGenParseMeta.sol";
import {LibCtPop} from "rain-math-binary-0.1.4/src/lib/LibCtPop.sol";
import {LibParseMetaFingerprint} from "test/lib/meta/LibParseMetaFingerprint.sol";

/// @title LibGenParseMetaWordWrittenAtExpanderLayerTest
/// @notice Every word is written at the layer `findBestExpander` assigned it.
contract LibGenParseMetaWordWrittenAtExpanderLayerTest is Test {
    function wordSet(uint256 salt, uint256 length) internal pure returns (AuthoringMetaV2[] memory) {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](length);
        for (uint256 i = 0; i < length; i++) {
            metas[i] = AuthoringMetaV2({word: keccak256(abi.encode(salt, i)), description: string(abi.encode(i))});
        }
        return metas;
    }

    function assertWrittenAt(
        bytes memory meta,
        uint256 layerStart,
        uint8 seed,
        uint256 expansion,
        AuthoringMetaV2 memory authoringMeta
    ) internal pure {
        (uint256 bitmap, uint256 hashed) = LibParseMeta.wordBitmapped(seed, authoringMeta.word);
        uint256 offset = layerStart + LibCtPop.ctpop(expansion & (bitmap - 1)) * META_ITEM_SIZE;
        assertEq(uint8(meta[offset]), abi.decode(bytes(authoringMeta.description), (uint256)), "index");
        uint256 fingerprint = (uint256(uint8(meta[offset + 1])) << 16) | (uint256(uint8(meta[offset + 2])) << 8)
            | uint256(uint8(meta[offset + 3]));
        assertEq(fingerprint, hashed & FINGERPRINT_MASK, "fingerprint");
    }

    /// forge-config: default.fuzz.runs = 256
    function testEachWordWrittenAtItsExpanderLayer(uint256 salt, uint256 length) external pure {
        length = bound(length, 1, 256);
        AuthoringMetaV2[] memory metas = wordSet(salt, length);
        {
            bytes32[] memory words = new bytes32[](length);
            for (uint256 i = 0; i < length; i++) {
                words[i] = metas[i].word;
            }
            vm.assume(!LibParseMetaFingerprint.findsDupes(words));
        }

        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, type(uint8).max);
        uint256 depth = uint8(meta[0]);

        AuthoringMetaV2[] memory remaining = metas;
        uint256 layer = 0;
        uint256 layerStart = META_PREFIX_SIZE + depth * META_EXPANSION_SIZE;
        uint256 checked = 0;
        while (remaining.length > 0) {
            (uint8 seed, uint256 expansion, AuthoringMetaV2[] memory rest) = LibGenParseMeta.findBestExpander(remaining);
            assertEq(uint8(meta[META_PREFIX_SIZE + layer * META_EXPANSION_SIZE]), seed, "seed");

            uint256 r = 0;
            for (uint256 i = 0; i < remaining.length; i++) {
                if (r < rest.length && rest[r].word == remaining[i].word) {
                    r++;
                } else {
                    assertWrittenAt(meta, layerStart, seed, expansion, remaining[i]);
                    checked++;
                }
            }

            layerStart += LibCtPop.ctpop(expansion) * META_ITEM_SIZE;
            remaining = rest;
            layer++;
        }
        assertEq(layer, depth, "depth");
        assertEq(checked, length, "checked");
    }
}
