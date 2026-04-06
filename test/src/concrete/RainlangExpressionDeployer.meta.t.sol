// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainlangExpressionDeployerDeploymentTest} from "test/abstract/RainlangExpressionDeployerDeploymentTest.sol";
import {DESCRIBED_BY_META_HASH} from "../../../src/concrete/RainlangExpressionDeployer.sol";

/// @title RainlangExpressionDeployerMetaTest
/// @notice Tests that the RainlangExpressionDeployer meta is correct. Also
/// tests basic functionality of the `IParserV1View` interface implementation, except
/// parsing which is tested more extensively elsewhere.
contract RainlangExpressionDeployerMetaTest is RainlangExpressionDeployerDeploymentTest {
    /// Test that the expected construction meta hash can be read from the
    /// deployer.
    function testRainlangExpressionDeployerExpectedConstructionMetaHash() external view {
        bytes32 actualConstructionMetaHash = I_DEPLOYER.describedByMetaV1();
        assertEq(actualConstructionMetaHash, DESCRIBED_BY_META_HASH);
    }
}
