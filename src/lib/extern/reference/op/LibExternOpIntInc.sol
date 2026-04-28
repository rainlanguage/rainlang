// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OperandV2} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibSubParse} from "../../../parse/LibSubParse.sol";
import {IInterpreterExternV4, StackItem} from "rain.interpreter.interface/interface/IInterpreterExternV4.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";

/// @dev Opcode index of the extern increment opcode. Needs to be manually kept
/// in sync with the extern opcode function pointers. Definitely write tests for
/// this to ensure a mismatch doesn't happen silently.
uint256 constant OP_INDEX_INCREMENT = 0;

/// @title LibExternOpIntInc
/// @notice This op is a simple increment of every input by 1. It is used to demonstrate
/// handling both multiple inputs and outputs in extern dispatching logic.
library LibExternOpIntInc {
    using LibDecimalFloat for Float;

    /// @notice Running the extern increments every input by 1. By allowing many inputs
    /// we can test multi input/output logic is implemented correctly for
    /// externs.
    /// @param inputs The input values to increment.
    /// @return The incremented values.
    //slither-disable-next-line dead-code
    function run(OperandV2, StackItem[] memory inputs) internal pure returns (StackItem[] memory) {
        // packLossless(1e37, -37) encodes the decimal float value 1.
        Float one = LibDecimalFloat.packLossless(1e37, -37);
        for (uint256 i = 0; i < inputs.length; i++) {
            Float a = Float.wrap(StackItem.unwrap(inputs[i]));
            a = a.add(one);
            inputs[i] = StackItem.wrap(Float.unwrap(a));
        }
        return inputs;
    }

    /// @notice The integrity check for the extern increment opcode. The inputs and
    /// outputs are the same always.
    /// @param inputs The number of inputs.
    /// @return The number of inputs.
    /// @return The number of outputs.
    //slither-disable-next-line dead-code
    function integrity(OperandV2, uint256 inputs, uint256) internal pure returns (uint256, uint256) {
        return (inputs, inputs);
    }

    /// @notice The sub parser for the extern increment opcode. It has no special logic
    /// so uses the default sub parser from `LibSubParse`.
    /// @param constantsHeight The current height of the constants array.
    /// @param ioByte The IO byte encoding inputs and outputs.
    /// @param operand The operand for this opcode.
    /// @return Whether the sub parse succeeded.
    /// @return The bytecode for the sub parse.
    /// @return The constants for the sub parse.
    //slither-disable-next-line dead-code
    function subParser(uint256 constantsHeight, uint256 ioByte, OperandV2 operand)
        internal
        view
        returns (bool, bytes memory, bytes32[] memory)
    {
        //slither-disable-next-line unused-return
        return LibSubParse.subParserExtern(
            IInterpreterExternV4(address(this)), constantsHeight, ioByte, operand, OP_INDEX_INCREMENT
        );
    }
}
