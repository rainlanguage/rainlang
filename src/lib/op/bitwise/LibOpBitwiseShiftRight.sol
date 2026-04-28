// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {UnsupportedBitwiseShiftAmount} from "../../../error/ErrBitwise.sol";

/// @title LibOpBitwiseShiftRight
/// @notice Opcode for shifting bits right. The shift amount is taken from the
/// operand so it is compile time constant.
library LibOpBitwiseShiftRight {
    /// @notice Shift bits right by the amount specified in the operand.
    /// @param operand The operand encoding the shift amount.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2 operand) internal pure returns (uint256, uint256) {
        uint256 shiftAmount = uint256(OperandV2.unwrap(operand) & bytes32(uint256(0xFFFF)));

        if (
            // Shift amount must not result in the output always being 0.
            // Shift amount must not result in a noop.
            shiftAmount > type(uint8).max || shiftAmount == 0
        ) {
            revert UnsupportedBitwiseShiftAmount(shiftAmount);
        }

        // Always 1 input and 1 output.
        return (1, 1);
    }

    /// @notice Shift bits right by the amount specified in the operand.
    /// @param operand The operand encoding the shift amount.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2 operand, Pointer stackTop) internal pure returns (Pointer) {
        assembly ("memory-safe") {
            mstore(stackTop, shr(and(operand, 0xFFFF), mload(stackTop)))
        }
        return stackTop;
    }

    /// @notice Reference implementation for shifting bits right.
    /// @param operand The operand encoding the shift amount.
    /// @param inputs The input values from the stack.
    /// @return The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2 operand, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory)
    {
        uint256 shiftAmount = uint256(OperandV2.unwrap(operand) & bytes32(uint256(0xFFFF)));
        inputs[0] = StackItem.wrap(bytes32(uint256(StackItem.unwrap(inputs[0])) >> shiftAmount));
        return inputs;
    }
}
