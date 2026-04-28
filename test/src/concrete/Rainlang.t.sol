// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {Rainlang} from "../../../src/concrete/Rainlang.sol";
import {LibInterpreterDeploy} from "../../../src/lib/deploy/LibInterpreterDeploy.sol";

contract RainlangTest is Test {
    function testExpressionDeployerAddress() external {
        Rainlang rainlang = new Rainlang();
        assertEq(rainlang.expressionDeployerAddress(), LibInterpreterDeploy.EXPRESSION_DEPLOYER_DEPLOYED_ADDRESS);
        assertTrue(rainlang.expressionDeployerAddress() != address(0));
    }

    function testInterpreterAddress() external {
        Rainlang rainlang = new Rainlang();
        assertEq(rainlang.interpreterAddress(), LibInterpreterDeploy.INTERPRETER_DEPLOYED_ADDRESS);
        assertTrue(rainlang.interpreterAddress() != address(0));
    }

    function testStoreAddress() external {
        Rainlang rainlang = new Rainlang();
        assertEq(rainlang.storeAddress(), LibInterpreterDeploy.STORE_DEPLOYED_ADDRESS);
        assertTrue(rainlang.storeAddress() != address(0));
    }

    function testParserAddress() external {
        Rainlang rainlang = new Rainlang();
        assertEq(rainlang.parserAddress(), LibInterpreterDeploy.PARSER_DEPLOYED_ADDRESS);
        assertTrue(rainlang.parserAddress() != address(0));
    }
}
