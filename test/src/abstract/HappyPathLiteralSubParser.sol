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

/// @dev Sub parser where matchSubParseLiteralDispatch always succeeds at
/// index 0, returning a known dispatch value. subParserLiteralParsers has a
/// single valid function pointer to echoLiteralParser.
contract HappyPathLiteralSubParser is BaseRainlangSubParser {
    function matchSubParseLiteralDispatch(uint256, uint256) internal pure override returns (bool, uint256, bytes32) {
        return (true, 0, bytes32(uint256(0x42)));
    }

    function subParserLiteralParsers() internal pure override returns (bytes memory) {
        unchecked {
            function(bytes32, uint256, uint256) internal pure returns (bytes32) lengthPointer;
            uint256 length = 1;
            assembly ("memory-safe") {
                lengthPointer := length
            }
            function(bytes32, uint256, uint256) internal pure returns (bytes32)[2] memory parsersFixed =
                [lengthPointer, echoLiteralParser];
            uint256[] memory parsersDynamic;
            assembly ("memory-safe") {
                parsersDynamic := parsersFixed
            }
            return LibConvert.unsafeTo16BitBytes(parsersDynamic);
        }
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
