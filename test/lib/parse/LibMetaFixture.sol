// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

import {AuthoringMetaV2} from "rain.interpreter.interface/interface/IParserV2.sol";
import {OperandV2, LibParseOperand} from "../../../src/lib/parse/LibParseOperand.sol";
import {LibParseState, ParseState} from "../../../src/lib/parse/LibParseState.sol";
import {LibConvert} from "rain.lib.typecast/LibConvert.sol";
import {LibAllStandardOps} from "../../../src/lib/op/LibAllStandardOps.sol";
import {LibGenParseMeta} from "rain.interpreter.interface/lib/codegen/LibGenParseMeta.sol";

uint256 constant FIXTURE_OPS_LENGTH = 18;

library LibMetaFixture {
    function newState(string memory s) internal pure returns (ParseState memory) {
        return LibParseState.newState(
            bytes(s), parseMetaV2(), operandHandlerFunctionPointers(), LibAllStandardOps.literalParserFunctionPointers()
        );
    }

    function authoringMetaV2() internal pure returns (AuthoringMetaV2[] memory) {
        AuthoringMetaV2[] memory meta = new AuthoringMetaV2[](FIXTURE_OPS_LENGTH);
        meta[0] = AuthoringMetaV2("stack", "reads from the stack");
        meta[1] = AuthoringMetaV2("constant", "copies a constant to the stack");
        meta[2] = AuthoringMetaV2("a", "a");
        meta[3] = AuthoringMetaV2("b", "b");
        meta[4] = AuthoringMetaV2("c", "c");
        meta[5] = AuthoringMetaV2("d", "d");
        meta[6] = AuthoringMetaV2("e", "e");
        meta[7] = AuthoringMetaV2("f", "f");
        meta[8] = AuthoringMetaV2("g", "g");
        meta[9] = AuthoringMetaV2("h", "h");
        meta[10] = AuthoringMetaV2("i", "i");
        meta[11] = AuthoringMetaV2("j", "j");
        meta[12] = AuthoringMetaV2("k", "k");
        meta[13] = AuthoringMetaV2("l", "l");
        meta[14] = AuthoringMetaV2("m", "m");
        meta[15] = AuthoringMetaV2("n", "n");
        meta[16] = AuthoringMetaV2("o", "o");
        meta[17] = AuthoringMetaV2("p", "p");
        return meta;
    }

    function parseMetaV2() internal pure returns (bytes memory) {
        return LibGenParseMeta.buildParseMetaV2(authoringMetaV2(), 1);
    }

    function operandHandlerFunctionPointers() internal pure returns (bytes memory) {
        function(bytes32[] memory) internal pure returns (OperandV2)[] memory handlers =
            new function(bytes32[] memory) internal pure returns (OperandV2)[](FIXTURE_OPS_LENGTH);
        handlers[0] = LibParseOperand.handleOperandSingleFull;
        handlers[1] = LibParseOperand.handleOperandSingleFull;
        // a
        handlers[2] = LibParseOperand.handleOperandDisallowed;
        // b
        handlers[3] = LibParseOperand.handleOperandSingleFull;
        // c
        handlers[4] = LibParseOperand.handleOperandDoublePerByteNoDefault;
        // d
        handlers[5] = LibParseOperand.handleOperandM1M1;
        // e
        handlers[6] = LibParseOperand.handleOperand8M1M1;
        // f
        handlers[7] = LibParseOperand.handleOperandDisallowed;
        // g
        handlers[8] = LibParseOperand.handleOperandDisallowed;
        // h
        handlers[9] = LibParseOperand.handleOperandDisallowed;
        // i
        handlers[10] = LibParseOperand.handleOperandDisallowed;
        // j
        handlers[11] = LibParseOperand.handleOperandDisallowed;
        // k
        handlers[12] = LibParseOperand.handleOperandDisallowed;
        // l
        handlers[13] = LibParseOperand.handleOperandDisallowed;
        // m
        handlers[14] = LibParseOperand.handleOperandDisallowed;
        // n
        handlers[15] = LibParseOperand.handleOperandDisallowed;
        // o
        handlers[16] = LibParseOperand.handleOperandDisallowed;
        // p
        handlers[17] = LibParseOperand.handleOperandDisallowed;
        uint256[] memory pointers;
        assembly ("memory-safe") {
            pointers := handlers
        }
        return LibConvert.unsafeTo16BitBytes(pointers);
    }
}
