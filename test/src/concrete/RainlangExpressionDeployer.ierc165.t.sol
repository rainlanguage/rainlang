// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {RainlangExpressionDeployer} from "../../../src/concrete/RainlangExpressionDeployer.sol";
import {IParserPragmaV1} from "rain.interpreter.interface/interface/IParserPragmaV1.sol";
import {IParserV2} from "rain.interpreter.interface/interface/IParserV2.sol";
import {IDescribedByMetaV1} from "rain.metadata/interface/IDescribedByMetaV1.sol";
import {IIntegrityToolingV1} from "rain.sol.codegen/interface/IIntegrityToolingV1.sol";

contract RainlangExpressionDeployerIERC165Test is Test {
    /// Test that ERC165 is implemented for all interfaces.
    function testRainlangExpressionDeployerIERC165(bytes4 badInterfaceId) external {
        vm.assume(badInterfaceId != type(IERC165).interfaceId);
        vm.assume(badInterfaceId != type(IDescribedByMetaV1).interfaceId);
        vm.assume(badInterfaceId != type(IParserV2).interfaceId);
        vm.assume(badInterfaceId != type(IParserPragmaV1).interfaceId);
        vm.assume(badInterfaceId != type(IIntegrityToolingV1).interfaceId);

        RainlangExpressionDeployer deployer = new RainlangExpressionDeployer();
        assertTrue(deployer.supportsInterface(type(IERC165).interfaceId));
        assertTrue(deployer.supportsInterface(type(IDescribedByMetaV1).interfaceId));
        assertTrue(deployer.supportsInterface(type(IParserV2).interfaceId));
        assertTrue(deployer.supportsInterface(type(IParserPragmaV1).interfaceId));
        assertTrue(deployer.supportsInterface(type(IIntegrityToolingV1).interfaceId));

        assertFalse(deployer.supportsInterface(badInterfaceId));
    }
}
