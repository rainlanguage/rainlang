// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {BaseRainlang} from "../../src/abstract/BaseRainlang.sol";
import {
    TEST_PARSER_ADDRESS,
    TEST_STORE_ADDRESS,
    TEST_INTERPRETER_ADDRESS,
    TEST_COMPILER_ADDRESS
} from "../lib/deploy/LibTestInterpreterDeploy.sol";
// Referenced by NatSpec only.
//forge-lint: disable-next-line(unused-import)
import {IRainlangV2} from "../../src/interface/IRainlangV2.sol";

/// @title TestRainlang
/// @notice `BaseRainlang` bound to the addresses `LibTestInterpreterDeploy`
/// places the test concretes at.
contract TestRainlang is BaseRainlang {
    /// @inheritdoc IRainlangV2
    function compilerAddress() external pure virtual override returns (address) {
        return TEST_COMPILER_ADDRESS;
    }

    /// @inheritdoc IRainlangV2
    function interpreterAddress() external pure virtual override returns (address) {
        return TEST_INTERPRETER_ADDRESS;
    }

    /// @inheritdoc IRainlangV2
    function storeAddress() external pure virtual override returns (address) {
        return TEST_STORE_ADDRESS;
    }

    /// @inheritdoc IRainlangV2
    function parserAddress() external pure virtual override returns (address) {
        return TEST_PARSER_ADDRESS;
    }
}
