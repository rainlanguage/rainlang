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
import {HappyPathLiteralSubParser} from "./HappyPathLiteralSubParser.sol";
import {NoMatchLiteralSubParser} from "./NoMatchLiteralSubParser.sol";
import {MismatchedLiteralSubParser} from "./MismatchedLiteralSubParser.sol";

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
