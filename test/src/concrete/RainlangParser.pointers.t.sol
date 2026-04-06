// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {
    RainlangParser,
    OPERAND_HANDLER_FUNCTION_POINTERS,
    LITERAL_PARSER_FUNCTION_POINTERS,
    PARSE_META,
    PARSE_META_BUILD_DEPTH
} from "../../../src/concrete/RainlangParser.sol";
import {LibAllStandardOps, AuthoringMetaV2} from "../../../src/lib/op/LibAllStandardOps.sol";
import {LibGenParseMeta} from "rain.interpreter.interface/lib/codegen/LibGenParseMeta.sol";

contract RainlangParserPointersTest is Test {
    function testOperandHandlerFunctionPointers() external {
        RainlangParser parser = new RainlangParser();
        bytes memory expected = parser.buildOperandHandlerFunctionPointers();
        bytes memory actual = OPERAND_HANDLER_FUNCTION_POINTERS;
        assertEq(actual, expected);
    }

    function testLiteralParserFunctionPointers() external {
        RainlangParser parser = new RainlangParser();
        bytes memory expected = parser.buildLiteralParserFunctionPointers();
        bytes memory actual = LITERAL_PARSER_FUNCTION_POINTERS;
        assertEq(actual, expected);
    }

    function testParserParseMeta() external pure {
        bytes memory authoringMetaBytes = LibAllStandardOps.authoringMetaV2();
        AuthoringMetaV2[] memory authoringMeta = abi.decode(authoringMetaBytes, (AuthoringMetaV2[]));
        bytes memory expected = LibGenParseMeta.buildParseMetaV2(authoringMeta, PARSE_META_BUILD_DEPTH);
        bytes memory actual = PARSE_META;
        assertEq(actual, expected);
    }
}
