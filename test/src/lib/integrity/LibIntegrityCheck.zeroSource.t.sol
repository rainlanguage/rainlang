// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainlangExpressionDeployerDeploymentTest} from "test/abstract/RainlangExpressionDeployerDeploymentTest.sol";
import {RainlangParser} from "../../../../src/concrete/RainlangParser.sol";
import {LibInterpreterDeploy} from "../../../../src/lib/deploy/LibInterpreterDeploy.sol";
import {LibBytecode} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";

contract LibIntegrityCheckZeroSourceTest is RainlangExpressionDeployerDeploymentTest {
    /// Empty input produces zero-source bytecode. The parser emits a single
    /// byte (sourceCount = 0), and the integrity check (run inside parse2)
    /// must handle this without reverting.
    function testZeroSourceEmptyInput() external view {
        (bytes memory bytecode,) = RainlangParser(LibInterpreterDeploy.PARSER_DEPLOYED_ADDRESS).unsafeParse("");
        assertEq(LibBytecode.sourceCount(bytecode), 0);
        assertEq(bytecode.length, 1);
    }

    /// Comment-only input also produces zero-source bytecode.
    function testZeroSourceCommentOnly() external view {
        (bytes memory bytecode,) =
            RainlangParser(LibInterpreterDeploy.PARSER_DEPLOYED_ADDRESS).unsafeParse("/* comment */");
        assertEq(LibBytecode.sourceCount(bytecode), 0);
        assertEq(bytecode.length, 1);
    }
}
