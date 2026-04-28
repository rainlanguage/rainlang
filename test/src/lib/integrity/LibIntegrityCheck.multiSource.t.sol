// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainlangExpressionDeployerDeploymentTest} from "test/abstract/RainlangExpressionDeployerDeploymentTest.sol";
import {RainlangParser} from "../../../../src/concrete/RainlangParser.sol";
import {LibInterpreterDeploy} from "../../../../src/lib/deploy/LibInterpreterDeploy.sol";
import {LibBytecode} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";

contract LibIntegrityCheckMultiSourceTest is RainlangExpressionDeployerDeploymentTest {
    /// Two-source expression must pass integrity and produce correct
    /// per-source metadata.
    function testIntegrityTwoSources() external view {
        (bytes memory bytecode,) =
            RainlangParser(LibInterpreterDeploy.PARSER_DEPLOYED_ADDRESS).unsafeParse("_: 1;_: 2, _: 3;");
        assertEq(LibBytecode.sourceCount(bytecode), 2);

        // Source 0: 1 op (constant), 1 output.
        assertEq(LibBytecode.sourceOpsCount(bytecode, 0), 1);
        (, uint256 outputs0) = LibBytecode.sourceInputsOutputsLength(bytecode, 0);
        assertEq(outputs0, 1);

        // Source 1: 2 ops (two constants), 2 outputs.
        assertEq(LibBytecode.sourceOpsCount(bytecode, 1), 2);
        (, uint256 outputs1) = LibBytecode.sourceInputsOutputsLength(bytecode, 1);
        assertEq(outputs1, 2);
    }

    /// Three-source expression with different shapes must pass integrity.
    function testIntegrityThreeSources() external view {
        (bytes memory bytecode,) = RainlangParser(LibInterpreterDeploy.PARSER_DEPLOYED_ADDRESS)
            .unsafeParse("_: 1;_: add(1 2);_: 3, _: 4, _: 5;");
        assertEq(LibBytecode.sourceCount(bytecode), 3);

        // Source 0: 1 op, 1 output.
        assertEq(LibBytecode.sourceOpsCount(bytecode, 0), 1);
        (, uint256 outputs0) = LibBytecode.sourceInputsOutputsLength(bytecode, 0);
        assertEq(outputs0, 1);

        // Source 1: 3 ops (2 constants + add), 1 output.
        assertEq(LibBytecode.sourceOpsCount(bytecode, 1), 3);
        (, uint256 outputs1) = LibBytecode.sourceInputsOutputsLength(bytecode, 1);
        assertEq(outputs1, 1);

        // Source 2: 3 ops (3 constants), 3 outputs.
        assertEq(LibBytecode.sourceOpsCount(bytecode, 2), 3);
        (, uint256 outputs2) = LibBytecode.sourceInputsOutputsLength(bytecode, 2);
        assertEq(outputs2, 3);
    }
}
