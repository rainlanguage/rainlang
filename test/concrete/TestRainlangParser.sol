// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {BaseRainlangParser, PARSE_META_BUILD_DEPTH} from "../../src/abstract/BaseRainlangParser.sol";
import {LibAllStandardOps, AuthoringMetaV2} from "../../src/lib/op/LibAllStandardOps.sol";
import {LibGenParseMeta} from "rainlang-interface-0.2.9/src/lib/codegen/LibGenParseMeta.sol";

/// @title TestRainlangParser
/// @notice `BaseRainlangParser` over the current source: the parse meta is
/// built from `LibAllStandardOps` at construction and the function pointer
/// tables are read from it at runtime, so nothing here comes from a generated
/// file.
contract TestRainlangParser is BaseRainlangParser {
    bytes internal sParseMeta;

    constructor() {
        sParseMeta = LibGenParseMeta.buildParseMetaV2(
            abi.decode(LibAllStandardOps.authoringMetaV2(), (AuthoringMetaV2[])), PARSE_META_BUILD_DEPTH
        );
    }

    /// @inheritdoc BaseRainlangParser
    function parseMeta() internal view virtual override returns (bytes memory) {
        return sParseMeta;
    }

    /// @inheritdoc BaseRainlangParser
    function operandHandlerFunctionPointers() internal pure virtual override returns (bytes memory) {
        return LibAllStandardOps.operandHandlerFunctionPointers();
    }

    /// @inheritdoc BaseRainlangParser
    function literalParserFunctionPointers() internal pure virtual override returns (bytes memory) {
        return LibAllStandardOps.literalParserFunctionPointers();
    }
}
