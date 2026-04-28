// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OperandV2} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibSubParse} from "../../../parse/LibSubParse.sol";

/// @title LibExternOpStackOperand
/// @notice This op copies its operand value to the stack by copying it to the constants
/// array at parse time. This means that it doesn't exist as an externed opcode,
/// the interpreter will run it directly, therefore it has no `run` or
/// `integrity` logic, only a sub parser. This demonstrates both how to
/// implement constants, and handling operands in the sub parser.
library LibExternOpStackOperand {
    /// @notice The sub parser for the stack operand opcode. Copies the operand
    /// value into the constants array so the interpreter can push it directly.
    /// @param constantsHeight The current height of the constants array.
    /// @param operand The operand value to copy to constants.
    /// @return Whether the sub parse succeeded.
    /// @return The bytecode for the sub parse.
    /// @return The constants for the sub parse.
    //slither-disable-next-line dead-code
    function subParser(uint256 constantsHeight, uint256, OperandV2 operand)
        internal
        pure
        returns (bool, bytes memory, bytes32[] memory)
    {
        //slither-disable-next-line unused-return
        return LibSubParse.subParserConstant(constantsHeight, OperandV2.unwrap(operand));
    }
}
