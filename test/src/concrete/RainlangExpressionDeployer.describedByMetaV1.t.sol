// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {RainlangExpressionDeployer} from "../../../src/concrete/RainlangExpressionDeployer.sol";
import {RainlangInterpreter} from "../../../src/concrete/RainlangInterpreter.sol";
import {RainlangStore} from "../../../src/concrete/RainlangStore.sol";
import {RainlangParser} from "../../../src/concrete/RainlangParser.sol";
string constant EXPRESSION_DEPLOYER_META_PATH = "meta/RainlangExpressionDeployer.rain.meta";

contract RainlangExpressionDeployerDescribedByMetaV1Test is Test {
    function testRainlangExpressionDeployerDescribedByMetaV1Happy() external {
        bytes memory describedByMeta = vm.readFileBinary(EXPRESSION_DEPLOYER_META_PATH);
        RainlangExpressionDeployer deployer = new RainlangExpressionDeployer();

        assertEq(keccak256(describedByMeta), deployer.describedByMetaV1());
    }
}
