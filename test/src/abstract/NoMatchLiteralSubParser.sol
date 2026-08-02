// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {BaseRainlangSubParser} from "../../../src/abstract/BaseRainlangSubParser.sol";

/// @dev Sub parser using default matchSubParseLiteralDispatch (returns false).
contract NoMatchLiteralSubParser is BaseRainlangSubParser {
    function describedByMetaV1() external pure override returns (bytes32) {
        return bytes32(0);
    }

    function buildLiteralParserFunctionPointers() external pure returns (bytes memory) {
        return "";
    }

    function buildOperandHandlerFunctionPointers() external pure returns (bytes memory) {
        return "";
    }

    function buildSubParserWordParsers() external pure returns (bytes memory) {
        return "";
    }
}
