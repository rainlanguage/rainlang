// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";

import {LibAllStandardOps} from "../../../src/lib/op/LibAllStandardOps.sol";

/// @title RainlangInterpreterTest
/// @notice Test suite for the interpreter's opcode function pointer table.
contract RainlangInterpreterTest is Test {
    /// The function pointers of the interpreter must be even non-zero length.
    function testRainlangInterpreterOddFunctionPointersLength() external pure {
        bytes memory pointers = LibAllStandardOps.opcodeFunctionPointers();
        assertTrue(pointers.length % 2 == 0);
        assertTrue(pointers.length > 0);
    }
}
