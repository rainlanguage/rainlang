// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {BaseRainlangSubParser} from "../../../src/abstract/BaseRainlangSubParser.sol";

/// @dev Sub parser where matchSubParseLiteralDispatch always succeeds with
/// index 1, but subParserLiteralParsers returns only 1 pointer (2 bytes).
/// This triggers SubParserIndexOutOfBounds(1, 1) in subParseLiteral2.
contract MismatchedLiteralSubParser is BaseRainlangSubParser {
    function matchSubParseLiteralDispatch(uint256, uint256) internal pure override returns (bool, uint256, bytes32) {
        return (true, 1, bytes32(0));
    }

    function subParserLiteralParsers() internal pure override returns (bytes memory) {
        // 1 pointer = 2 bytes, so parsersLength = 1. Index 1 is out of range.
        return hex"0001";
    }

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
