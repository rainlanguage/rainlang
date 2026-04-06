// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainlangExpressionDeployerDeploymentTest} from "test/abstract/RainlangExpressionDeployerDeploymentTest.sol";
import {OpcodeIOOverflow} from "../../../../src/error/ErrParse.sol";

/// @title LibParseStateOpcodeIOOverflowTest
/// @notice Tests for OpcodeIOOverflow in endLine.
contract LibParseStateOpcodeIOOverflowTest is RainlangExpressionDeployerDeploymentTest {
    /// A word with 16 paren-enclosed inputs overflows the 4-bit ioByte
    /// input nybble (max 15), triggering OpcodeIOOverflow.
    function testOpcodeIOOverflowInputs() external {
        // int-add with 16 inputs: int-add(1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1)
        bytes memory rainlang = bytes("_: int-add(1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1);");

        vm.expectRevert(abi.encodeWithSelector(OpcodeIOOverflow.selector, 43));
        I_PARSER.unsafeParse(rainlang);
    }

    /// A single RHS word with 16 LHS names overflows the 4-bit ioByte
    /// output nybble (max 15), triggering OpcodeIOOverflow.
    function testOpcodeIOOverflowOutputs() external {
        // 16 LHS names for a single RHS word exceeds the 4-bit output nybble.
        // Use a 0-input word so inputs don't overflow first.
        bytes memory rainlang = bytes("a b c d e f g h i j k l m n o p: block-number();");

        vm.expectRevert(abi.encodeWithSelector(OpcodeIOOverflow.selector, 47));
        I_PARSER.unsafeParse(rainlang);
    }
}
