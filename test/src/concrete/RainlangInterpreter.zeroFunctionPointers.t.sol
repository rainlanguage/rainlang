// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {RainlangInterpreter} from "../../../src/concrete/RainlangInterpreter.sol";
import {ZeroFunctionPointers} from "../../../src/error/ErrEval.sol";

contract ZeroFPRainlangInterpreter is RainlangInterpreter {
    function opcodeFunctionPointers() internal pure override returns (bytes memory) {
        return hex"";
    }
}

contract RainlangInterpreterZeroFunctionPointersTest is Test {
    /// Deploying a RainlangInterpreter with empty function pointers must revert.
    function testZeroFunctionPointersReverts() external {
        vm.expectRevert(abi.encodeWithSelector(ZeroFunctionPointers.selector));
        new ZeroFPRainlangInterpreter();
    }

    /// The standard RainlangInterpreter must deploy successfully.
    function testStandardRainlangInterpreterDeploys() external {
        new RainlangInterpreter();
    }
}
