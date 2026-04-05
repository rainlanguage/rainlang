// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {RainlangInterpreter} from "../../../src/concrete/RainlangInterpreter.sol";
import {LibExtrospectBytecode} from "rain.extrospection/lib/LibExtrospectBytecode.sol";
import {INTERPRETER_DISALLOWED_OPS} from "rain.extrospection/lib/EVMOpcodes.sol";

contract RainlangInterpreterExtrospectTest is Test {
    /// The interpreter bytecode MUST NOT contain any reachable state-changing
    /// EVM opcodes. This ensures eval cannot mutate state even if the caller
    /// uses CALL instead of STATICCALL.
    function testInterpreterNoDisallowedOpcodes() external {
        RainlangInterpreter interpreter = new RainlangInterpreter();
        bytes memory bytecode = address(interpreter).code;
        uint256 reachable = LibExtrospectBytecode.scanEVMOpcodesReachableInBytecode(bytecode);
        assertEq(reachable & INTERPRETER_DISALLOWED_OPS, 0, "Interpreter has disallowed reachable opcodes");
    }
}
