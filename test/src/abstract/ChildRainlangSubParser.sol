// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {IERC165} from "@openzeppelin-contracts-5.6.1/utils/introspection/IERC165.sol";
import {ISubParserV4} from "rain-interpreter-interface-0.1.0/src/interface/ISubParserV4.sol";
import {BaseRainlangSubParser} from "../../../src/abstract/BaseRainlangSubParser.sol";
import {IDescribedByMetaV1} from "rain-metadata-0.1.0/src/interface/IDescribedByMetaV1.sol";
import {IParserToolingV1} from "rain-sol-codegen-0.1.0/src/interface/IParserToolingV1.sol";
import {ISubParserToolingV1} from "rain-sol-codegen-0.1.0/src/interface/ISubParserToolingV1.sol";

/// @dev We need a contract that is deployable in order to test the abstract
/// base contract.
contract ChildRainlangSubParser is BaseRainlangSubParser {
    function describedByMetaV1() external pure override returns (bytes32) {
        return 0;
    }

    function buildLiteralParserFunctionPointers() external pure returns (bytes memory) {
        return new bytes(0);
    }

    function buildOperandHandlerFunctionPointers() external pure returns (bytes memory) {
        return new bytes(0);
    }

    function buildSubParserWordParsers() external pure returns (bytes memory) {
        return new bytes(0);
    }
}
