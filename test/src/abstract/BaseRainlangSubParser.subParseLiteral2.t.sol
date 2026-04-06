// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {BaseRainlangSubParser, SubParserIndexOutOfBounds} from "../../../src/abstract/BaseRainlangSubParser.sol";
import {LibConvert} from "rain.lib.typecast/LibConvert.sol";

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

/// @title BaseRainlangSubParserLiteral2Test
/// @notice Direct unit tests for subParseLiteral2: happy path, no-match, and
/// index-out-of-bounds.
contract BaseRainlangSubParserLiteral2Test is Test {
    /// Happy path: dispatch matches, literal parser is called, returns
    /// (true, parsedValue).
    function testSubParseLiteral2HappyPath() external {
        HappyPathLiteralSubParser subParser = new HappyPathLiteralSubParser();

        // Minimal data: 2-byte dispatch length (1) + 1 byte dispatch body.
        bytes memory data = bytes.concat(bytes2(uint16(1)), bytes1(0));

        (bool success, bytes32 value) = subParser.subParseLiteral2(data);
        assertTrue(success);
        assertEq(value, bytes32(uint256(0x42)));
    }

    /// No-match path: dispatch does not match, returns (false, 0).
    function testSubParseLiteral2NoMatch() external {
        NoMatchLiteralSubParser subParser = new NoMatchLiteralSubParser();

        bytes memory data = bytes.concat(bytes2(uint16(1)), bytes1(0));

        (bool success, bytes32 value) = subParser.subParseLiteral2(data);
        assertFalse(success);
        assertEq(value, bytes32(0));
    }

    /// subParseLiteral2 must revert when the dispatch index is out of range.
    function testSubParseLiteral2RevertsIndexOutOfBounds() external {
        MismatchedLiteralSubParser subParser = new MismatchedLiteralSubParser();

        // Minimal data: 2-byte dispatch length + 1 byte dispatch body.
        bytes memory data = bytes.concat(bytes2(uint16(1)), bytes1(0));

        vm.expectRevert(abi.encodeWithSelector(SubParserIndexOutOfBounds.selector, uint256(1), uint256(1)));
        subParser.subParseLiteral2(data);
    }
}
