// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {BaseRainlangSubParser, SubParserIndexOutOfBounds} from "../../../src/abstract/BaseRainlangSubParser.sol";
import {LibConvert} from "rain-lib-typecast-0.1.0/src/LibConvert.sol";

/// @dev Simple literal parser that returns the dispatch value unchanged.
function echoLiteralParser(bytes32 dispatchValue, uint256, uint256) pure returns (bytes32) {
    return dispatchValue;
}

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
