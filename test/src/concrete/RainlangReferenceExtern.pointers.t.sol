// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {
    RainlangReferenceExtern,
    OPCODE_FUNCTION_POINTERS,
    INTEGRITY_FUNCTION_POINTERS,
    SUB_PARSER_WORD_PARSERS,
    AuthoringMetaV2,
    SUB_PARSER_PARSE_META,
    LibRainlangReferenceExtern,
    LITERAL_PARSER_FUNCTION_POINTERS,
    OPERAND_HANDLER_FUNCTION_POINTERS
} from "../../../src/concrete/extern/RainlangReferenceExtern.sol";
import {LibGenParseMeta} from "rain.interpreter.interface/lib/codegen/LibGenParseMeta.sol";

contract RainlangReferenceExternPointersTest is Test {
    function testOpcodeFunctionPointers() external {
        RainlangReferenceExtern extern = new RainlangReferenceExtern();
        bytes memory expected = extern.buildOpcodeFunctionPointers();
        bytes memory actual = OPCODE_FUNCTION_POINTERS;
        assertEq(actual, expected);
    }

    function testIntegrityFunctionPointers() external {
        RainlangReferenceExtern extern = new RainlangReferenceExtern();
        bytes memory expected = extern.buildIntegrityFunctionPointers();
        bytes memory actual = INTEGRITY_FUNCTION_POINTERS;
        assertEq(actual, expected);
    }

    function testSubParserParseMeta() external pure {
        bytes memory authoringMetaBytes = LibRainlangReferenceExtern.authoringMetaV2();
        AuthoringMetaV2[] memory authoringMeta = abi.decode(authoringMetaBytes, (AuthoringMetaV2[]));
        bytes memory expected = LibGenParseMeta.buildParseMetaV2(authoringMeta, 2);
        bytes memory actual = SUB_PARSER_PARSE_META;
        assertEq(actual, expected);
    }

    function testSubParserLiteralParsers() external {
        RainlangReferenceExtern subParser = new RainlangReferenceExtern();
        bytes memory expected = subParser.buildLiteralParserFunctionPointers();
        bytes memory actual = LITERAL_PARSER_FUNCTION_POINTERS;
        assertEq(actual, expected);
    }

    function testSubParserFunctionPointers() external {
        RainlangReferenceExtern extern = new RainlangReferenceExtern();
        bytes memory expected = extern.buildSubParserWordParsers();
        bytes memory actual = SUB_PARSER_WORD_PARSERS;
        assertEq(actual, expected);
    }

    function testSubParserOperandParsers() external {
        RainlangReferenceExtern extern = new RainlangReferenceExtern();
        bytes memory expected = extern.buildOperandHandlerFunctionPointers();
        bytes memory actual = OPERAND_HANDLER_FUNCTION_POINTERS;
        assertEq(actual, expected);
    }
}
