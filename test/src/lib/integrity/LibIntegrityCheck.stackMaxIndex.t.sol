// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    RainlangExpressionDeployerDeploymentTest
} from "test/abstract/RainlangExpressionDeployerDeploymentTest.sol";
import {RainlangParser} from "../../../../src/concrete/RainlangParser.sol";
import {LibInterpreterDeploy} from "../../../../src/lib/deploy/LibInterpreterDeploy.sol";
import {LibBytecode} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";

contract LibIntegrityCheckStackMaxIndexTest is RainlangExpressionDeployerDeploymentTest {
    /// stackMaxIndex must track the peak stack height, not the final height.
    /// `_: add(1 2);` pushes two constants (peak = 2), then add consumes
    /// both and produces one result (final = 1). The stackAllocation in the
    /// bytecode must equal the peak (2), not the final output count (1).
    function testStackMaxIndexTracksPeak() external view {
        (bytes memory bytecode,) =
            RainlangParser(LibInterpreterDeploy.PARSER_DEPLOYED_ADDRESS).unsafeParse("_: add(1 2);");

        uint256 allocation = LibBytecode.sourceStackAllocation(bytecode, 0);
        (, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, 0);

        // Peak (2) != final (1), and allocation tracks the peak.
        assertEq(allocation, 2);
        assertEq(outputs, 1);
        assertTrue(allocation > outputs);
    }
}
