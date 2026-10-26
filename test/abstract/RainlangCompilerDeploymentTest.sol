// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {BaseRainlangStore} from "../../src/abstract/BaseRainlangStore.sol";
import {BaseRainlangParser} from "../../src/abstract/BaseRainlangParser.sol";
import {BaseRainlangInterpreter} from "../../src/abstract/BaseRainlangInterpreter.sol";
import {BaseRainlangCompiler} from "../../src/abstract/BaseRainlangCompiler.sol";
import {LibRainDeploy} from "rain-deploy-0.1.22/src/lib/LibRainDeploy.sol";
import {
    LibTestInterpreterDeploy,
    TEST_PARSER_ADDRESS,
    TEST_STORE_ADDRESS,
    TEST_INTERPRETER_ADDRESS,
    TEST_COMPILER_ADDRESS
} from "../lib/deploy/LibTestInterpreterDeploy.sol";
import {LibTOFUTokenDecimals} from "rain-tofu-erc20-decimals-0.1.4/src/lib/LibTOFUTokenDecimals.sol";
import {
    CREATION_CODE as DECIMAL_FLOAT_CREATION_CODE,
    DEPLOYED_ADDRESS as DECIMAL_FLOAT_ADDRESS,
    BYTECODE_HASH as DECIMAL_FLOAT_BYTECODE_HASH
} from "rain-math-float-deploy-0.1.7/src/generated/0_1_6/DecimalFloat.sol";

/// @title RainlangCompilerDeploymentTest
/// @notice Binds a parser, store, interpreter and compiler for the
/// tests that need a whole Rainlang to parse and eval against. By default they
/// are the test concretes built from this repo's source; `deployRainlang` is
/// the one place to bind a deployed set instead.
abstract contract RainlangCompilerDeploymentTest is Test {
    //solhint-disable-next-line private-vars-leading-underscore
    BaseRainlangCompiler internal immutable I_COMPILER;
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
    /// @return The compiler.
    function deployRainlang()
        internal
        virtual
        returns (BaseRainlangParser, BaseRainlangStore, BaseRainlangInterpreter, BaseRainlangCompiler)
    {
        LibTestInterpreterDeploy.etchTestRainlang(vm);
        return (
            BaseRainlangParser(TEST_PARSER_ADDRESS),
            BaseRainlangStore(TEST_STORE_ADDRESS),
            BaseRainlangInterpreter(TEST_INTERPRETER_ADDRESS),
            BaseRainlangCompiler(TEST_COMPILER_ADDRESS)
        );
    }

    constructor() {
        beforeOpTestConstructor();
        (I_PARSER, I_STORE, I_INTERPRETER, I_COMPILER) = deployRainlang();

        if (
            address(LibTOFUTokenDecimals.TOFU_DECIMALS_DEPLOYMENT).codehash
                != LibTOFUTokenDecimals.TOFU_DECIMALS_EXPECTED_CODE_HASH
        ) {
            LibRainDeploy.etchZoltuFactory(vm);
            LibRainDeploy.deployZoltu(LibTOFUTokenDecimals.TOFU_DECIMALS_EXPECTED_CREATION_CODE);
        }

        if (DECIMAL_FLOAT_ADDRESS.codehash != DECIMAL_FLOAT_BYTECODE_HASH) {
            LibRainDeploy.etchZoltuFactory(vm);
            LibRainDeploy.deployZoltu(DECIMAL_FLOAT_CREATION_CODE);
        }
    }
}
