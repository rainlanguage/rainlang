// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibRainDeploy} from "rain-deploy-0.1.2/src/lib/LibRainDeploy.sol";
import {LibInterpreterDeploy} from "../../../../src/lib/deploy/LibInterpreterDeploy.sol";

/// @title LibInterpreterDeployProdTest
/// @notice Forks each supported network and verifies that all five interpreter
/// contracts are deployed at the expected addresses with the expected codehash.
contract LibInterpreterDeployProdTest is Test {
    function _checkAllContracts() internal view {
        assertTrue(LibInterpreterDeploy.PARSER_DEPLOYED_ADDRESS.code.length > 0, "Parser not deployed");
        assertEq(LibInterpreterDeploy.PARSER_DEPLOYED_ADDRESS.codehash, LibInterpreterDeploy.PARSER_DEPLOYED_CODEHASH);

        assertTrue(LibInterpreterDeploy.STORE_DEPLOYED_ADDRESS.code.length > 0, "Store not deployed");
        assertEq(LibInterpreterDeploy.STORE_DEPLOYED_ADDRESS.codehash, LibInterpreterDeploy.STORE_DEPLOYED_CODEHASH);

        assertTrue(LibInterpreterDeploy.INTERPRETER_DEPLOYED_ADDRESS.code.length > 0, "Interpreter not deployed");
        assertEq(
            LibInterpreterDeploy.INTERPRETER_DEPLOYED_ADDRESS.codehash,
            LibInterpreterDeploy.INTERPRETER_DEPLOYED_CODEHASH
        );

        assertTrue(
            LibInterpreterDeploy.EXPRESSION_DEPLOYER_DEPLOYED_ADDRESS.code.length > 0, "ExpressionDeployer not deployed"
        );
        assertEq(
            LibInterpreterDeploy.EXPRESSION_DEPLOYER_DEPLOYED_ADDRESS.codehash,
            LibInterpreterDeploy.EXPRESSION_DEPLOYER_DEPLOYED_CODEHASH
        );

        assertTrue(LibInterpreterDeploy.RAINLANG_DEPLOYED_ADDRESS.code.length > 0, "Rainlang not deployed");
        assertEq(
            LibInterpreterDeploy.RAINLANG_DEPLOYED_ADDRESS.codehash, LibInterpreterDeploy.RAINLANG_DEPLOYED_CODEHASH
        );
    }

    /// All five contracts MUST be deployed on Arbitrum.
    function testProdDeployArbitrum() external {
        vm.createSelectFork(LibRainDeploy.ARBITRUM_ONE);
        _checkAllContracts();
    }

    /// All five contracts MUST be deployed on Base.
    function testProdDeployBase() external {
        vm.createSelectFork(LibRainDeploy.BASE);
        _checkAllContracts();
    }

    /// All five contracts MUST be deployed on Base Sepolia.
    function testProdDeployBaseSepolia() external {
        vm.createSelectFork(LibRainDeploy.BASE_SEPOLIA);
        _checkAllContracts();
    }

    /// All five contracts MUST be deployed on Flare.
    function testProdDeployFlare() external {
        vm.createSelectFork(LibRainDeploy.FLARE);
        _checkAllContracts();
    }

    /// All five contracts MUST be deployed on Polygon.
    function testProdDeployPolygon() external {
        vm.createSelectFork(LibRainDeploy.POLYGON);
        _checkAllContracts();
    }
}
