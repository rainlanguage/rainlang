// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {OPCODE_FUNCTION_POINTERS} from "../../../src/concrete/RainlangInterpreter.sol";

/// @title RainlangInterpreterTest
/// @notice Test suite for RainlangInterpreter.
contract RainlangInterpreterTest is Test {
    /// The function pointers of the interpreter must be even non-zero length.
    function testRainlangInterpreterOddFunctionPointersLength() external pure {
        assertTrue(OPCODE_FUNCTION_POINTERS.length % 2 == 0);
        assertTrue(OPCODE_FUNCTION_POINTERS.length > 0);
    }
}
