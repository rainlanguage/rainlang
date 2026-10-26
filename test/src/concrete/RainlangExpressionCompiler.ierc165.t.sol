// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";

import {IERC165} from "@openzeppelin-contracts-5.7.0/utils/introspection/IERC165.sol";
import {TestRainlangExpressionCompiler} from "test/concrete/TestRainlangExpressionCompiler.sol";
import {IParserPragmaV1} from "rainlang-interface-0.2.13/src/interface/IParserPragmaV1.sol";
import {IParserV2} from "rainlang-interface-0.2.13/src/interface/IParserV2.sol";
import {IDescribedByMetaV1} from "rain-metadata-0.1.43/src/interface/IDescribedByMetaV1.sol";
import {IIntegrityToolingV1} from "rain-sol-codegen-0.1.39/src/interface/IIntegrityToolingV1.sol";

contract RainlangExpressionCompilerIERC165Test is Test {
    /// Test that ERC165 is implemented for all interfaces.
    function testRainlangExpressionCompilerIERC165(bytes4 badInterfaceId) external {
        vm.assume(badInterfaceId != type(IERC165).interfaceId);
        vm.assume(badInterfaceId != type(IDescribedByMetaV1).interfaceId);
        vm.assume(badInterfaceId != type(IParserV2).interfaceId);
        vm.assume(badInterfaceId != type(IParserPragmaV1).interfaceId);
        vm.assume(badInterfaceId != type(IIntegrityToolingV1).interfaceId);

        TestRainlangExpressionCompiler compiler = new TestRainlangExpressionCompiler();
        assertTrue(compiler.supportsInterface(type(IERC165).interfaceId));
        assertTrue(compiler.supportsInterface(type(IDescribedByMetaV1).interfaceId));
        assertTrue(compiler.supportsInterface(type(IParserV2).interfaceId));
        assertTrue(compiler.supportsInterface(type(IParserPragmaV1).interfaceId));
        assertTrue(compiler.supportsInterface(type(IIntegrityToolingV1).interfaceId));

        assertFalse(compiler.supportsInterface(badInterfaceId));
    }
}
