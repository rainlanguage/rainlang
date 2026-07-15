// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {RainlangInterpreter} from "../../../src/concrete/RainlangInterpreter.sol";
import {ZeroFunctionPointers} from "../../../src/error/ErrEval.sol";

contract ZeroFPRainlangInterpreter is RainlangInterpreter {
    function opcodeFunctionPointers() internal pure override returns (bytes memory) {
        return hex"";
    }
}
