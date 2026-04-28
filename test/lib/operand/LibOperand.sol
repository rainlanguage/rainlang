// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

import {OperandV2} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

library LibOperand {
    function build(uint8 inputs, uint8 outputs, uint16 operandData) internal pure returns (OperandV2) {
        require(inputs < 0x10, "inputs must be less than 16");
        require(outputs < 0x10, "outputs must be less than 16");
        return OperandV2.wrap(bytes32(uint256(outputs) << 0x14 | uint256(inputs) << 0x10 | uint256(operandData)));
    }
}
