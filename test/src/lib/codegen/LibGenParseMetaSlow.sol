// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {LibParseMeta} from "../../../../src/lib/parse/LibParseMeta.sol";
import {LibCtPop} from "rain-math-binary-0.1.4/src/lib/LibCtPop.sol";
import {AuthoringMetaV2} from "../../../../src/interface/IParserV2.sol";

library LibGenParseMetaSlow {
    /// Reference implementation of findBestExpander that searches all 256 seeds
    /// (0 through 255 inclusive). Returns only the best seed and its popcount
    /// so tests can compare against the optimised implementation.
    function findBestExpanderSlow(AuthoringMetaV2[] memory metas)
        internal
        pure
        returns (uint8 bestSeed, uint256 bestCt)
    {
        for (uint256 seed = 0; seed <= type(uint8).max; seed++) {
            uint256 expansion = 0;
            for (uint256 i = 0; i < metas.length; i++) {
                (uint256 shifted,) = LibParseMeta.wordBitmapped(seed, metas[i].word);
                expansion = shifted | expansion;
            }
            uint256 ct = LibCtPop.ctpop(expansion);
            if (ct > bestCt) {
                bestCt = ct;
                //forge-lint: disable-next-line(unsafe-typecast)
                bestSeed = uint8(seed);
            }
            // Perfect expansion — no need to keep searching.
            if (ct == metas.length) {
                break;
            }
        }
    }
}
