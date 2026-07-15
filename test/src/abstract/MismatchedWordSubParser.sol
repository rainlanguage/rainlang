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

/// @dev Sub parser with 2 words in meta but only 1 word parser pointer.
/// Looking up the word at index 1 triggers SubParserIndexOutOfBounds.
contract MismatchedWordSubParser is BaseRainlangSubParser {
    function subParserParseMeta() internal pure override returns (bytes memory) {
        AuthoringMetaV2[] memory meta = new AuthoringMetaV2[](2);
        meta[0] = AuthoringMetaV2("aaa", "");
        meta[1] = AuthoringMetaV2("bbb", "");
        return LibGenParseMeta.buildParseMetaV2(meta, 2);
    }

    function subParserOperandHandlers() internal pure override returns (bytes memory) {
        unchecked {
            function(bytes32[] memory) internal pure returns (OperandV2) lengthPointer;
            uint256 length = 2;
            assembly ("memory-safe") {
                lengthPointer := length
            }
            function(bytes32[] memory) internal pure returns (OperandV2)[3] memory handlersFixed =
                [lengthPointer, LibParseOperand.handleOperandDisallowed, LibParseOperand.handleOperandDisallowed];
            uint256[] memory handlersDynamic;
            assembly ("memory-safe") {
                handlersDynamic := handlersFixed
            }
            return LibConvert.unsafeTo16BitBytes(handlersDynamic);
        }
    }

    function subParserWordParsers() internal pure override returns (bytes memory) {
        // Only 1 word parser pointer (2 bytes), so parsersLength = 1.
        // Any index >= 1 is out of range.
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
