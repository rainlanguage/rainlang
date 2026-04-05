// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {RainlangStore} from "../../src/concrete/RainlangStore.sol";
import {RainlangParser} from "../../src/concrete/RainlangParser.sol";
import {RainlangInterpreter} from "../../src/concrete/RainlangInterpreter.sol";
import {RainlangExpressionDeployer} from "../../src/concrete/RainlangExpressionDeployer.sol";
import {LibRainDeploy} from "rain.deploy/lib/LibRainDeploy.sol";
import {LibInterpreterDeploy} from "../../src/lib/deploy/LibInterpreterDeploy.sol";
import {LibTOFUTokenDecimals} from "rain.tofu.erc20-decimals/lib/LibTOFUTokenDecimals.sol";

/// @title RainlangExpressionDeployerDeploymentTest
/// @notice Tests that the RainlangExpressionDeployer meta is correct. Also
/// tests basic functionality of the `IParserV1View` interface implementation.
abstract contract RainlangExpressionDeployerDeploymentTest is Test {
    //solhint-disable-next-line private-vars-leading-underscore
    RainlangExpressionDeployer internal immutable I_DEPLOYER;
    //solhint-disable-next-line private-vars-leading-underscore
    RainlangInterpreter internal immutable I_INTERPRETER;
    //solhint-disable-next-line private-vars-leading-underscore
    RainlangStore internal immutable I_STORE;
    //solhint-disable-next-line private-vars-leading-underscore
    RainlangParser internal immutable I_PARSER;

    function beforeOpTestConstructor() internal virtual {}

    constructor() {
        beforeOpTestConstructor();

        LibInterpreterDeploy.etchRainlang(vm);

        if (
            address(LibTOFUTokenDecimals.TOFU_DECIMALS_DEPLOYMENT).codehash
                != LibTOFUTokenDecimals.TOFU_DECIMALS_EXPECTED_CODE_HASH
        ) {
            LibRainDeploy.etchZoltuFactory(vm);
            LibRainDeploy.deployZoltu(LibTOFUTokenDecimals.TOFU_DECIMALS_EXPECTED_CREATION_CODE);
        }

        I_PARSER = RainlangParser(LibInterpreterDeploy.PARSER_DEPLOYED_ADDRESS);
        I_INTERPRETER = RainlangInterpreter(LibInterpreterDeploy.INTERPRETER_DEPLOYED_ADDRESS);
        I_STORE = RainlangStore(LibInterpreterDeploy.STORE_DEPLOYED_ADDRESS);
        I_DEPLOYER = RainlangExpressionDeployer(LibInterpreterDeploy.EXPRESSION_DEPLOYER_DEPLOYED_ADDRESS);
    }
}
