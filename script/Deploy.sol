// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Script, console2} from "forge-std/Script.sol";
import {LibRainDeploy} from "rain.deploy/lib/LibRainDeploy.sol";
import {LibInterpreterDeploy} from "../src/lib/deploy/LibInterpreterDeploy.sol";
import {LibDecimalFloatDeploy} from "rain.math.float/lib/deploy/LibDecimalFloatDeploy.sol";
import {UnknownDeploymentSuite} from "../src/error/ErrDeploy.sol";
import {LibTOFUTokenDecimals} from "rain.tofu.erc20-decimals/lib/LibTOFUTokenDecimals.sol";
import {CREATION_CODE as PARSER_CREATION_CODE} from "../src/generated/RainlangParser.pointers.sol";
import {CREATION_CODE as STORE_CREATION_CODE} from "../src/generated/RainlangStore.pointers.sol";
import {CREATION_CODE as INTERPRETER_CREATION_CODE} from "../src/generated/RainlangInterpreter.pointers.sol";
import {
    CREATION_CODE as EXPRESSION_DEPLOYER_CREATION_CODE
} from "../src/generated/RainlangExpressionDeployer.pointers.sol";
import {CREATION_CODE as RAINLANG_CREATION_CODE} from "../src/generated/Rainlang.pointers.sol";

/// @dev Deployment suite selector for the parser.
bytes32 constant DEPLOYMENT_SUITE_PARSER = keccak256("parser");
/// @dev Deployment suite selector for the store.
bytes32 constant DEPLOYMENT_SUITE_STORE = keccak256("store");
/// @dev Deployment suite selector for the interpreter.
bytes32 constant DEPLOYMENT_SUITE_INTERPRETER = keccak256("interpreter");
/// @dev Deployment suite selector for the expression deployer.
bytes32 constant DEPLOYMENT_SUITE_EXPRESSION_DEPLOYER = keccak256("expression-deployer");
/// @dev Deployment suite selector for Rainlang.
bytes32 constant DEPLOYMENT_SUITE_RAINLANG = keccak256("rainlang");

/// @title Deploy
/// @notice Forge script that deploys a single interpreter component to all
/// supported networks. The `DEPLOYMENT_SUITE` env var selects which component
/// to deploy: "parser", "store", "interpreter", "expression-deployer", or
/// "rainlang". Defaults to "parser" if not set. Uses precompiled
/// creation code from the generated pointers files rather than compiling
/// contracts at deploy time.
contract Deploy is Script {
    /// Storage mapping required by the `LibRainDeploy.deployAndBroadcast` API
    /// to record dependency code hashes across networks.
    mapping(string => mapping(address => bytes32)) internal sDepCodeHashes;

    /// Deploys the component selected by the `DEPLOYMENT_SUITE` env var.
    /// Reverts if the suite is not recognised.
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYMENT_KEY");

        address[] memory deps = new address[](1);
        deps[0] = LibDecimalFloatDeploy.ZOLTU_DEPLOYED_LOG_TABLES_ADDRESS;

        bytes32 suite = keccak256(bytes(vm.envOr("DEPLOYMENT_SUITE", string("parser"))));

        if (suite == DEPLOYMENT_SUITE_PARSER) {
            console2.log("Deploying RainlangParser...");
            LibRainDeploy.deployAndBroadcast(
                vm,
                LibRainDeploy.supportedNetworks(),
                deployerPrivateKey,
                PARSER_CREATION_CODE,
                "src/concrete/RainlangParser.sol:RainlangParser",
                LibInterpreterDeploy.PARSER_DEPLOYED_ADDRESS,
                LibInterpreterDeploy.PARSER_DEPLOYED_CODEHASH,
                deps,
                sDepCodeHashes
            );
        } else if (suite == DEPLOYMENT_SUITE_STORE) {
            console2.log("Deploying RainlangStore...");
            LibRainDeploy.deployAndBroadcast(
                vm,
                LibRainDeploy.supportedNetworks(),
                deployerPrivateKey,
                STORE_CREATION_CODE,
                "src/concrete/RainlangStore.sol:RainlangStore",
                LibInterpreterDeploy.STORE_DEPLOYED_ADDRESS,
                LibInterpreterDeploy.STORE_DEPLOYED_CODEHASH,
                deps,
                sDepCodeHashes
            );
        } else if (suite == DEPLOYMENT_SUITE_INTERPRETER) {
            console2.log("Deploying RainlangInterpreter...");
            address[] memory interpreterDeps = new address[](2);
            interpreterDeps[0] = LibDecimalFloatDeploy.ZOLTU_DEPLOYED_LOG_TABLES_ADDRESS;
            interpreterDeps[1] = address(LibTOFUTokenDecimals.TOFU_DECIMALS_DEPLOYMENT);
            LibRainDeploy.deployAndBroadcast(
                vm,
                LibRainDeploy.supportedNetworks(),
                deployerPrivateKey,
                INTERPRETER_CREATION_CODE,
                "src/concrete/RainlangInterpreter.sol:RainlangInterpreter",
                LibInterpreterDeploy.INTERPRETER_DEPLOYED_ADDRESS,
                LibInterpreterDeploy.INTERPRETER_DEPLOYED_CODEHASH,
                interpreterDeps,
                sDepCodeHashes
            );
        } else if (suite == DEPLOYMENT_SUITE_EXPRESSION_DEPLOYER) {
            console2.log("Deploying RainlangExpressionDeployer...");
            address[] memory deployerDeps = new address[](5);
            deployerDeps[0] = LibDecimalFloatDeploy.ZOLTU_DEPLOYED_LOG_TABLES_ADDRESS;
            deployerDeps[1] = address(LibTOFUTokenDecimals.TOFU_DECIMALS_DEPLOYMENT);
            deployerDeps[2] = LibInterpreterDeploy.PARSER_DEPLOYED_ADDRESS;
            deployerDeps[3] = LibInterpreterDeploy.STORE_DEPLOYED_ADDRESS;
            deployerDeps[4] = LibInterpreterDeploy.INTERPRETER_DEPLOYED_ADDRESS;
            LibRainDeploy.deployAndBroadcast(
                vm,
                LibRainDeploy.supportedNetworks(),
                deployerPrivateKey,
                EXPRESSION_DEPLOYER_CREATION_CODE,
                "src/concrete/RainlangExpressionDeployer.sol:RainlangExpressionDeployer",
                LibInterpreterDeploy.EXPRESSION_DEPLOYER_DEPLOYED_ADDRESS,
                LibInterpreterDeploy.EXPRESSION_DEPLOYER_DEPLOYED_CODEHASH,
                deployerDeps,
                sDepCodeHashes
            );
        } else if (suite == DEPLOYMENT_SUITE_RAINLANG) {
            console2.log("Deploying Rainlang...");
            address[] memory registryDeps = new address[](5);
            registryDeps[0] = address(LibTOFUTokenDecimals.TOFU_DECIMALS_DEPLOYMENT);
            registryDeps[1] = LibInterpreterDeploy.PARSER_DEPLOYED_ADDRESS;
            registryDeps[2] = LibInterpreterDeploy.STORE_DEPLOYED_ADDRESS;
            registryDeps[3] = LibInterpreterDeploy.INTERPRETER_DEPLOYED_ADDRESS;
            registryDeps[4] = LibInterpreterDeploy.EXPRESSION_DEPLOYER_DEPLOYED_ADDRESS;
            LibRainDeploy.deployAndBroadcast(
                vm,
                LibRainDeploy.supportedNetworks(),
                deployerPrivateKey,
                RAINLANG_CREATION_CODE,
                "src/concrete/Rainlang.sol:Rainlang",
                LibInterpreterDeploy.RAINLANG_DEPLOYED_ADDRESS,
                LibInterpreterDeploy.RAINLANG_DEPLOYED_CODEHASH,
                registryDeps,
                sDepCodeHashes
            );
        } else {
            revert UnknownDeploymentSuite(suite);
        }
    }
}
