// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {UnknownWord} from "../../../../src/error/ErrParse.sol";
import {ISubParserV4} from "rain.interpreter.interface/interface/ISubParserV4.sol";
import {LibAllStandardOps} from "../../../../src/lib/op/LibAllStandardOps.sol";

contract LibSubParseUnknownWordTest is Test {
    using LibParseState for ParseState;
    using LibParse for ParseState;

    /// External wrapper so expectRevert works.
    function externalParseUnknownWord(bytes memory data, address subParser) external view {
        ParseState memory state = LibParseState.newState(data, "", "", "");
        state.pushSubParser(0, bytes32(uint256(uint160(subParser))));
        (bytes memory bytecode, bytes32[] memory constants) = state.parse();
        (bytecode, constants);
    }

    /// External wrapper with literal parsers for operand value parsing.
    function externalParseUnknownWordWithLiteralParsers(bytes memory data, address subParser) external view {
        ParseState memory state =
            LibParseState.newState(data, "", "", LibAllStandardOps.literalParserFunctionPointers());
        state.pushSubParser(0, bytes32(uint256(uint160(subParser))));
        (bytes memory bytecode, bytes32[] memory constants) = state.parse();
        (bytecode, constants);
    }

    /// When the only sub-parser rejects a word, parse must revert with
    /// UnknownWord.
    function testUnknownWordSingleSubParser(string memory name) external {
        address subParser = makeAddr(name);

        // Mock the sub-parser to reject all words.
        vm.mockCall(
            subParser,
            abi.encodeWithSelector(ISubParserV4.subParseWord2.selector),
            abi.encode(false, bytes(""), new bytes32[](0))
        );

        vm.expectRevert(abi.encodeWithSelector(UnknownWord.selector, "foo"));
        this.externalParseUnknownWord(bytes("_: foo();"), subParser);
    }

    /// Unknown word at maximum valid length (31 bytes) exercises the bytecode
    /// construction at the word length boundary.
    function testUnknownWordMaxLength() external {
        address subParser = makeAddr("maxLength");

        vm.mockCall(
            subParser,
            abi.encodeWithSelector(ISubParserV4.subParseWord2.selector),
            abi.encode(false, bytes(""), new bytes32[](0))
        );

        // 31-byte word is the maximum before WordSize reverts.
        vm.expectRevert(abi.encodeWithSelector(UnknownWord.selector, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"));
        this.externalParseUnknownWord(bytes("_: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa();"), subParser);
    }

    /// Unknown word with operand values exercises the bytecode construction
    /// with operand data appended after the word.
    function testUnknownWordWithOperandValues() external {
        address subParser = makeAddr("operandValues");

        vm.mockCall(
            subParser,
            abi.encodeWithSelector(ISubParserV4.subParseWord2.selector),
            abi.encode(false, bytes(""), new bytes32[](0))
        );

        vm.expectRevert(abi.encodeWithSelector(UnknownWord.selector, "foo"));
        this.externalParseUnknownWordWithLiteralParsers(bytes("_: foo<1 2 3>();"), subParser);
    }

    /// Unknown word with single-character name (minimum length) exercises
    /// the bytecode construction at the lower bound.
    function testUnknownWordMinLength() external {
        address subParser = makeAddr("minLength");

        vm.mockCall(
            subParser,
            abi.encodeWithSelector(ISubParserV4.subParseWord2.selector),
            abi.encode(false, bytes(""), new bytes32[](0))
        );

        vm.expectRevert(abi.encodeWithSelector(UnknownWord.selector, "z"));
        this.externalParseUnknownWord(bytes("_: z();"), subParser);
    }
}
