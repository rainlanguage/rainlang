// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {
    BaseRainlangSubParser,
    SubParserIndexOutOfBounds,
    AuthoringMetaV2
} from "../../../src/abstract/BaseRainlangSubParser.sol";
import {LibGenParseMeta} from "rain-interpreter-interface-0.1.0/src/lib/codegen/LibGenParseMeta.sol";
import {LibParseOperand} from "../../../src/lib/parse/LibParseOperand.sol";
import {LibConvert} from "rain-lib-typecast-0.1.0/src/LibConvert.sol";
import {OperandV2} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterV4.sol";
import {MismatchedWordSubParser} from "./MismatchedWordSubParser.sol";
import {EmptyWordParsersSubParser} from "./EmptyWordParsersSubParser.sol";

/// @title BaseRainlangSubParserWord2Test
/// @notice Direct unit tests for subParseWord2.
contract BaseRainlangSubParserWord2Test is Test {
    /// Calling subParseWord2 with a word that maps to index 1 when only 1
    /// word parser exists must revert with SubParserIndexOutOfBounds.
    function testSubParseWord2RevertsIndexOutOfBounds() external {
        MismatchedWordSubParser subParser = new MismatchedWordSubParser();

        bytes memory word = bytes("bbb");
        bytes memory data = bytes.concat(
            bytes2(0), // constantsHeight
            bytes1(0), // ioByte
            bytes2(uint16(word.length)), // word length
            word, // word data
            bytes32(0) // operand values array (length 0)
        );

        vm.expectRevert(abi.encodeWithSelector(SubParserIndexOutOfBounds.selector, uint256(1), uint256(1)));
        subParser.subParseWord2(data);
    }

    /// Empty word parsers table: even index 0 is out of range.
    function testSubParseWord2RevertsEmptyWordParsers() external {
        EmptyWordParsersSubParser subParser = new EmptyWordParsersSubParser();

        bytes memory word = bytes("aaa");
        bytes memory data = bytes.concat(
            bytes2(0), // constantsHeight
            bytes1(0), // ioByte
            bytes2(uint16(word.length)), // word length
            word, // word data
            bytes32(0) // operand values array (length 0)
        );

        vm.expectRevert(abi.encodeWithSelector(SubParserIndexOutOfBounds.selector, uint256(0), uint256(0)));
        subParser.subParseWord2(data);
    }
}
