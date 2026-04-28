// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OperandV2} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibSubParse} from "../../../parse/LibSubParse.sol";
import {CONTEXT_BASE_COLUMN, CONTEXT_BASE_ROW_SENDER} from "rain.interpreter.interface/lib/caller/LibContext.sol";

/// @title LibExternOpContextSender
/// @notice This op is a simple reference to the sender of the transaction that called
/// the interpreter. It is used to demonstrate how to implement context
/// references.
library LibExternOpContextSender {
    /// @notice The sub parser for the sender context opcode. It has no special
    /// logic so uses the default sub parser from `LibSubParse`.
    /// @param constantsHeight The current height of the constants array (unused).
    /// @param ioByte The IO byte encoding inputs and outputs (unused).
    /// @param operand The operand for this opcode (unused).
    /// @return Whether the sub parse succeeded.
    /// @return The bytecode for the sub parse.
    /// @return The constants for the sub parse.
    //slither-disable-next-line dead-code
    function subParser(uint256 constantsHeight, uint256 ioByte, OperandV2 operand)
        internal
        pure
        returns (bool, bytes memory, bytes32[] memory)
    {
        (constantsHeight, ioByte, operand);
        //slither-disable-next-line unused-return
        return LibSubParse.subParserContext(CONTEXT_BASE_COLUMN, CONTEXT_BASE_ROW_SENDER);
    }
}
