// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {
    RainlangExpressionDeployer,
    INTEGRITY_FUNCTION_POINTERS
} from "../../../src/concrete/RainlangExpressionDeployer.sol";

contract RainlangExpressionDeployerPointersTest is Test {
    function testIntegrityFunctionPointers() external {
        RainlangExpressionDeployer deployer = new RainlangExpressionDeployer();
        bytes memory expected = deployer.buildIntegrityFunctionPointers();
        bytes memory actual = INTEGRITY_FUNCTION_POINTERS;
        assertEq(actual, expected);
    }
}
