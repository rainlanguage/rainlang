// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainlangExpressionDeployerDeploymentTest} from "test/abstract/RainlangExpressionDeployerDeploymentTest.sol";
import {LibIntegrityCheck} from "../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {LibAllStandardOps} from "../../../../src/lib/op/LibAllStandardOps.sol";

/// @title LibIntegrityCheckIoTest
/// @notice Verifies that integrityCheck2 returns correctly encoded io bytes.
contract LibIntegrityCheckIoTest is RainlangExpressionDeployerDeploymentTest {
    /// External wrapper so the library call can be used with parser-built bytecode.
    function externalIntegrityCheck(bytes memory bytecode, bytes32[] memory constants)
        external
        view
        returns (bytes memory)
    {
        return LibIntegrityCheck.integrityCheck2(LibAllStandardOps.integrityFunctionPointers(), bytecode, constants);
    }

    /// Single source with 0 inputs and 1 output.
    function testIntegrityCheck2IoSingleSource() external view {
        (bytes memory bytecode, bytes32[] memory constants) = I_PARSER.unsafeParse(bytes("_: 1;"));
        bytes memory io = this.externalIntegrityCheck(bytecode, constants);
        assertEq(io.length, 2, "io length for 1 source");
        assertEq(uint8(io[0]), 0, "source 0 inputs");
        assertEq(uint8(io[1]), 1, "source 0 outputs");
    }

    /// Two sources with different output counts.
    function testIntegrityCheck2IoTwoSources() external view {
        (bytes memory bytecode, bytes32[] memory constants) = I_PARSER.unsafeParse(bytes("_: 1;_: 2, _: 3;"));
        bytes memory io = this.externalIntegrityCheck(bytecode, constants);
        assertEq(io.length, 4, "io length for 2 sources");
        assertEq(uint8(io[0]), 0, "source 0 inputs");
        assertEq(uint8(io[1]), 1, "source 0 outputs");
        assertEq(uint8(io[2]), 0, "source 1 inputs");
        assertEq(uint8(io[3]), 2, "source 1 outputs");
    }

    /// Three sources with varying shapes.
    function testIntegrityCheck2IoThreeSources() external view {
        (bytes memory bytecode, bytes32[] memory constants) =
            I_PARSER.unsafeParse(bytes("_: 1;_: add(1 2);_: 3, _: 4, _: 5;"));
        bytes memory io = this.externalIntegrityCheck(bytecode, constants);
        assertEq(io.length, 6, "io length for 3 sources");
        assertEq(uint8(io[0]), 0, "source 0 inputs");
        assertEq(uint8(io[1]), 1, "source 0 outputs");
        assertEq(uint8(io[2]), 0, "source 1 inputs");
        assertEq(uint8(io[3]), 1, "source 1 outputs");
        assertEq(uint8(io[4]), 0, "source 2 inputs");
        assertEq(uint8(io[5]), 3, "source 2 outputs");
    }
}
