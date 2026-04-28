// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {RainlangExpressionDeployer} from "../../../src/concrete/RainlangExpressionDeployer.sol";
import {RainlangStore} from "../../../src/concrete/RainlangStore.sol";
import {RainlangParser} from "../../../src/concrete/RainlangParser.sol";
import {RainlangInterpreter} from "../../../src/concrete/RainlangInterpreter.sol";

/// @title RainlangExpressionDeployerDeployCheckTest
/// @notice Test that the RainlangExpressionDeployer deploy check reverts if the
/// passed config does not match expectations.
contract RainlangExpressionDeployerDeployCheckTest is Test {
    /// Test the deployer can deploy if everything is valid.
    function testRainlangExpressionDeployerDeployNoEIP1820() external {
        new RainlangExpressionDeployer();
    }
}
