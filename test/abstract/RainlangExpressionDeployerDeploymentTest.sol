// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {BaseRainlangStore} from "../../src/abstract/BaseRainlangStore.sol";
import {BaseRainlangParser} from "../../src/abstract/BaseRainlangParser.sol";
import {BaseRainlangInterpreter} from "../../src/abstract/BaseRainlangInterpreter.sol";
import {BaseRainlangExpressionDeployer} from "../../src/abstract/BaseRainlangExpressionDeployer.sol";
import {LibRainDeploy} from "rain-deploy-0.1.8/src/lib/LibRainDeploy.sol";
import {
    LibTestInterpreterDeploy,
    TEST_PARSER_ADDRESS,
    TEST_STORE_ADDRESS,
    TEST_INTERPRETER_ADDRESS,
    TEST_EXPRESSION_DEPLOYER_ADDRESS
} from "../lib/deploy/LibTestInterpreterDeploy.sol";
import {LibTOFUTokenDecimals} from "rain-tofu-erc20-decimals-0.1.1/src/lib/LibTOFUTokenDecimals.sol";

/// @title RainlangExpressionDeployerDeploymentTest
/// @notice Binds a parser, store, interpreter and expression deployer for the
/// tests that need a whole Rainlang to parse and eval against. By default they
/// are the test concretes built from this repo's source; `deployRainlang` is
/// the one place to bind a deployed set instead.
abstract contract RainlangExpressionDeployerDeploymentTest is Test {
    //solhint-disable-next-line private-vars-leading-underscore
    BaseRainlangExpressionDeployer internal immutable I_DEPLOYER;
    //solhint-disable-next-line private-vars-leading-underscore
    BaseRainlangInterpreter internal immutable I_INTERPRETER;
    //solhint-disable-next-line private-vars-leading-underscore
    BaseRainlangStore internal immutable I_STORE;
    //solhint-disable-next-line private-vars-leading-underscore
    BaseRainlangParser internal immutable I_PARSER;

    function beforeOpTestConstructor() internal virtual {}

    /// Places the Rainlang under test and returns its four components.
    /// @return The parser.
    /// @return The store.
    /// @return The interpreter.
    /// @return The expression deployer.
    function deployRainlang()
        internal
        virtual
        returns (BaseRainlangParser, BaseRainlangStore, BaseRainlangInterpreter, BaseRainlangExpressionDeployer)
    {
        LibTestInterpreterDeploy.etchTestRainlang(vm);
        return (
            BaseRainlangParser(TEST_PARSER_ADDRESS),
            BaseRainlangStore(TEST_STORE_ADDRESS),
            BaseRainlangInterpreter(TEST_INTERPRETER_ADDRESS),
            BaseRainlangExpressionDeployer(TEST_EXPRESSION_DEPLOYER_ADDRESS)
        );
    }

    constructor() {
        beforeOpTestConstructor();
        (I_PARSER, I_STORE, I_INTERPRETER, I_DEPLOYER) = deployRainlang();

        if (
            address(LibTOFUTokenDecimals.TOFU_DECIMALS_DEPLOYMENT).codehash
                != LibTOFUTokenDecimals.TOFU_DECIMALS_EXPECTED_CODE_HASH
        ) {
            LibRainDeploy.etchZoltuFactory(vm);
            LibRainDeploy.deployZoltu(LibTOFUTokenDecimals.TOFU_DECIMALS_EXPECTED_CREATION_CODE);
        }
    }
}
