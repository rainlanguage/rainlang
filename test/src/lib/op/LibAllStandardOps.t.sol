// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {LibAllStandardOps, ALL_STANDARD_OPS_LENGTH} from "../../../../src/lib/op/LibAllStandardOps.sol";
import {AuthoringMetaV2} from "rain.interpreter.interface/interface/IParserV2.sol";
import {LITERAL_PARSERS_LENGTH} from "../../../../src/lib/parse/literal/LibParseLiteral.sol";

/// @title LibAllStandardOpsTest
/// @notice Some basic guard rails around the `LibAllStandardOps` library. Most of the
/// logic can only be tested by deploying an interpreter and running it.
contract LibAllStandardOpsTest is Test {
    /// Test that the dynamic length of the function pointers is correct.
    function testIntegrityFunctionPointersLength() external pure {
        bytes memory integrityFunctionPointers = LibAllStandardOps.integrityFunctionPointers();
        assertEq(integrityFunctionPointers.length, ALL_STANDARD_OPS_LENGTH * 2);
    }

    /// Test that the dynamic length of the function pointers is correct.
    function testOpcodeFunctionPointersLength() external pure {
        bytes memory functionPointers = LibAllStandardOps.opcodeFunctionPointers();
        // Each function pointer is 2 bytes.
        assertEq(functionPointers.length, ALL_STANDARD_OPS_LENGTH * 2);
    }

    /// All four parallel arrays (authoring meta, operand handlers, integrity
    /// pointers, opcode pointers) must have consistent lengths. A mismatch
    /// means opcodes would be dispatched to the wrong function.
    function testFourArrayOrderingConsistency() external pure {
        bytes memory integrityPointers = LibAllStandardOps.integrityFunctionPointers();
        bytes memory opcodePointers = LibAllStandardOps.opcodeFunctionPointers();
        bytes memory operandHandlers = LibAllStandardOps.operandHandlerFunctionPointers();

        bytes memory authoringMeta = LibAllStandardOps.authoringMetaV2();
        AuthoringMetaV2[] memory words = abi.decode(authoringMeta, (AuthoringMetaV2[]));

        // All four arrays must have the same number of entries.
        uint256 expected = ALL_STANDARD_OPS_LENGTH * 2;
        assertEq(integrityPointers.length, expected);
        assertEq(opcodePointers.length, expected);
        assertEq(operandHandlers.length, expected);
        assertEq(words.length * 2, expected);
    }

    /// Test that the literal parser function pointers length matches
    /// LITERAL_PARSERS_LENGTH.
    function testLiteralParserFunctionPointersLength() external pure {
        bytes memory pointers = LibAllStandardOps.literalParserFunctionPointers();
        assertEq(pointers.length, LITERAL_PARSERS_LENGTH * 2);
    }

    /// Test that the operand handler function pointers length matches
    /// ALL_STANDARD_OPS_LENGTH.
    function testOperandHandlerFunctionPointersLength() external pure {
        bytes memory pointers = LibAllStandardOps.operandHandlerFunctionPointers();
        assertEq(pointers.length, ALL_STANDARD_OPS_LENGTH * 2);
    }

    /// Test that authoringMetaV2 word names are correct and in the expected
    /// order. The first four opcodes (stack, constant, extern, context) MUST
    /// be in this exact order for parsing to work.
    function testAuthoringMetaV2Content() external pure {
        bytes memory authoringMeta = LibAllStandardOps.authoringMetaV2();
        AuthoringMetaV2[] memory words = abi.decode(authoringMeta, (AuthoringMetaV2[]));

        assertEq(words.length, ALL_STANDARD_OPS_LENGTH);

        // The first four opcodes must be in this order for parsing.
        // Safe: string literals are <= 32 bytes, right-padded by Solidity.
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[0].word, bytes32("stack"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[1].word, bytes32("constant"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[2].word, bytes32("extern"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[3].word, bytes32("context"));

        // Verify every word name and ordering.
        // bitwise/
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[4].word, bytes32("bitwise-and"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[5].word, bytes32("bitwise-count-ones"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[6].word, bytes32("bitwise-decode"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[7].word, bytes32("bitwise-encode"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[8].word, bytes32("bitwise-or"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[9].word, bytes32("bitwise-shift-left"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[10].word, bytes32("bitwise-shift-right"));
        // call/
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[11].word, bytes32("call"));
        // crypto/
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[12].word, bytes32("hash"));
        // erc20/
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[13].word, bytes32("erc20-allowance"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[14].word, bytes32("erc20-balance-of"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[15].word, bytes32("erc20-total-supply"));
        // erc20/uint256/
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[16].word, bytes32("uint256-erc20-allowance"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[17].word, bytes32("uint256-erc20-balance-of"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[18].word, bytes32("uint256-erc20-total-supply"));
        // erc5313/
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[19].word, bytes32("erc5313-owner"));
        // erc721/
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[20].word, bytes32("erc721-balance-of"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[21].word, bytes32("erc721-owner-of"));
        // erc721/uint256/
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[22].word, bytes32("uint256-erc721-balance-of"));
        // evm/
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[23].word, bytes32("block-number"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[24].word, bytes32("block-timestamp"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[25].word, bytes32("now"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[26].word, bytes32("chain-id"));
        // logic/
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[27].word, bytes32("any"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[28].word, bytes32("binary-equal-to"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[29].word, bytes32("conditions"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[30].word, bytes32("ensure"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[31].word, bytes32("equal-to"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[32].word, bytes32("every"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[33].word, bytes32("greater-than"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[34].word, bytes32("greater-than-or-equal-to"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[35].word, bytes32("if"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[36].word, bytes32("is-zero"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[37].word, bytes32("less-than"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[38].word, bytes32("less-than-or-equal-to"));
        // math/
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[39].word, bytes32("abs"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[40].word, bytes32("add"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[41].word, bytes32("avg"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[42].word, bytes32("ceil"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[43].word, bytes32("div"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[44].word, bytes32("e"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[45].word, bytes32("exp"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[46].word, bytes32("exp2"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[47].word, bytes32("floor"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[48].word, bytes32("frac"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[49].word, bytes32("gm"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[50].word, bytes32("headroom"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[51].word, bytes32("inv"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[52].word, bytes32("max"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[53].word, bytes32("max-negative-value"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[54].word, bytes32("max-positive-value"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[55].word, bytes32("min"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[56].word, bytes32("min-negative-value"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[57].word, bytes32("min-positive-value"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[58].word, bytes32("mul"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[59].word, bytes32("power"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[60].word, bytes32("sqrt"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[61].word, bytes32("sub"));
        // math/growth/
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[62].word, bytes32("exponential-growth"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[63].word, bytes32("linear-growth"));
        // math/uint256/
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[64].word, bytes32("uint256-add"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[65].word, bytes32("uint256-div"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[66].word, bytes32("uint256-max-value"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[67].word, bytes32("uint256-mul"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[68].word, bytes32("uint256-power"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[69].word, bytes32("uint256-sub"));
        // store/
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[70].word, bytes32("get"));
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(words[71].word, bytes32("set"));
    }
}
