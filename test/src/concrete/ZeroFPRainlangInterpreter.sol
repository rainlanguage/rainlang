// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainlangInterpreter} from "../../../src/concrete/RainlangInterpreter.sol";

contract ZeroFPRainlangInterpreter is RainlangInterpreter {
    function opcodeFunctionPointers() internal pure override returns (bytes memory) {
        return hex"";
    }
}
