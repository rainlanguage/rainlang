// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainlangExpressionDeployerDeploymentTest} from "test/abstract/RainlangExpressionDeployerDeploymentTest.sol";
import {LibBytecode} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";

contract RainlangParserUnsafeParseTest is RainlangExpressionDeployerDeploymentTest {
    /// Parsing a simple hex literal expression returns correct bytecode
    /// structure and constant value.
    function testUnsafeParseHappyPath() external view {
        (bytes memory bytecode, bytes32[] memory constants) = I_PARSER.unsafeParse(bytes("_: 0xdeadbeef;"));

        assertEq(LibBytecode.sourceCount(bytecode), 1);
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 1);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 0);
        assertEq(outputs, 1);

        assertEq(constants.length, 1);
        assertEq(constants[0], bytes32(uint256(0xdeadbeef)));
    }

    /// Empty input produces bytecode with only a zero sourceCount byte
    /// and no constants.
    function testUnsafeParseEmpty() external view {
        (bytes memory bytecode, bytes32[] memory constants) = I_PARSER.unsafeParse(bytes(""));

        assertEq(bytecode.length, 1);
        assertEq(LibBytecode.sourceCount(bytecode), 0);
        assertEq(constants.length, 0);
    }
}
