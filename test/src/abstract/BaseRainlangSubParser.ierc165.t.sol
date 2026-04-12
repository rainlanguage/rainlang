// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {ISubParserV4} from "rain.interpreter.interface/interface/ISubParserV4.sol";
import {BaseRainlangSubParser} from "../../../src/abstract/BaseRainlangSubParser.sol";
import {IDescribedByMetaV1} from "rain.metadata/interface/IDescribedByMetaV1.sol";
import {IParserToolingV1} from "rain.sol.codegen/interface/IParserToolingV1.sol";
import {ISubParserToolingV1} from "rain.sol.codegen/interface/ISubParserToolingV1.sol";

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

/// @title BaseRainlangSubParserTest
/// @notice Test suite for BaseRainlangSubParser.
contract BaseRainlangSubParserIERC165Test is Test {
    /// Test that ERC165 and ISubParserV3 are supported interfaces as
    /// per ERC165.
    function testRainlangSubParserIERC165(uint32 badInterfaceIdUint) external {
        // https://github.com/foundry-rs/foundry/issues/6115
        bytes4 badInterfaceId = bytes4(badInterfaceIdUint);

        vm.assume(badInterfaceId != type(IERC165).interfaceId);
        vm.assume(badInterfaceId != type(ISubParserV4).interfaceId);
        vm.assume(badInterfaceId != type(IDescribedByMetaV1).interfaceId);
        vm.assume(badInterfaceId != type(IParserToolingV1).interfaceId);
        vm.assume(badInterfaceId != type(ISubParserToolingV1).interfaceId);

        ChildRainlangSubParser subParser = new ChildRainlangSubParser();
        assertTrue(subParser.supportsInterface(type(IERC165).interfaceId));
        assertTrue(subParser.supportsInterface(type(ISubParserV4).interfaceId));
        assertTrue(subParser.supportsInterface(type(IDescribedByMetaV1).interfaceId));
        assertTrue(subParser.supportsInterface(type(IParserToolingV1).interfaceId));
        assertTrue(subParser.supportsInterface(type(ISubParserToolingV1).interfaceId));
        assertFalse(subParser.supportsInterface(badInterfaceId));
    }
}
