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

/// @dev Sub parser with 1 word in meta but zero word parser pointers.
/// Looking up the word at index 0 triggers SubParserIndexOutOfBounds(0, 0).
contract EmptyWordParsersSubParser is BaseRainlangSubParser {
    function subParserParseMeta() internal pure override returns (bytes memory) {
        AuthoringMetaV2[] memory meta = new AuthoringMetaV2[](1);
        meta[0] = AuthoringMetaV2("aaa", "");
        return LibGenParseMeta.buildParseMetaV2(meta, 1);
    }

    function subParserOperandHandlers() internal pure override returns (bytes memory) {
        unchecked {
            function(bytes32[] memory) internal pure returns (OperandV2) lengthPointer;
            uint256 length = 1;
            assembly ("memory-safe") {
                lengthPointer := length
            }
            function(bytes32[] memory) internal pure returns (OperandV2)[2] memory handlersFixed =
                [lengthPointer, LibParseOperand.handleOperandDisallowed];
            uint256[] memory handlersDynamic;
            assembly ("memory-safe") {
                handlersDynamic := handlersFixed
            }
            return LibConvert.unsafeTo16BitBytes(handlersDynamic);
        }
    }

    function subParserWordParsers() internal pure override returns (bytes memory) {
        // Empty — parsersLength = 0.
        return "";
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
