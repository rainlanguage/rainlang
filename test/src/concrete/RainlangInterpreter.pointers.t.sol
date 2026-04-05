// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {RainlangInterpreter, OPCODE_FUNCTION_POINTERS} from "../../../src/concrete/RainlangInterpreter.sol";

contract RainlangInterpreterPointersTest is Test {
    function testOpcodeFunctionPointers() external {
        RainlangInterpreter interpreter = new RainlangInterpreter();
        bytes memory expected = interpreter.buildOpcodeFunctionPointers();
        bytes memory actual = OPCODE_FUNCTION_POINTERS;
        assertEq(actual, expected);
    }
}
