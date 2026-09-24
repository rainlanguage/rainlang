// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {Pointer} from "rain-solmem-0.1.28/src/lib/LibPointer.sol";

/// @title LibOpBitwiseAnd
/// @notice Opcode for computing bitwise AND across every item on the stack up
/// to the inputs limit. Two inputs is the binary case, `bitwise-and(a b)`, and
/// more than two is the variadic case, `bitwise-and(a b c)`, which folds to
/// `a & b & c`. AND is associative and commutative, so the fold order is not
/// observable.
library LibOpBitwiseAnd {
    /// @notice `bitwise-and` integrity check. Requires at least 2 inputs and
    /// produces 1 output.
    /// @param operand Low 4 bits of the high byte encode the input count.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2 operand) internal pure returns (uint256, uint256) {
        // There must be at least two inputs.
        uint256 inputs = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;
        inputs = inputs > 1 ? inputs : 2;
        return (inputs, 1);
    }

    /// @notice Bitwise AND every item on the stack up to the inputs limit.
    /// @param operand Low 4 bits of the high byte encode the input count.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2 operand, Pointer stackTop) internal pure returns (Pointer) {
        unchecked {
            uint256 length = 0x20 * (uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F);
            Pointer cursor = stackTop;
            Pointer end = Pointer.wrap(Pointer.unwrap(stackTop) + length);
            Pointer stackTopAfter = Pointer.wrap(Pointer.unwrap(end) - 0x20);

            bytes32 acc;
            assembly ("memory-safe") {
                acc := mload(cursor)
            }
            cursor = Pointer.wrap(Pointer.unwrap(cursor) + 0x20);

            while (Pointer.unwrap(cursor) < Pointer.unwrap(end)) {
                assembly ("memory-safe") {
                    acc := and(acc, mload(cursor))
                }
                cursor = Pointer.wrap(Pointer.unwrap(cursor) + 0x20);
            }

            assembly ("memory-safe") {
                mstore(stackTopAfter, acc)
            }

            return stackTopAfter;
        }
    }

    /// @notice Reference implementation for bitwise AND.
    /// @param inputs The input values from the stack.
    /// @return The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory)
    {
        bytes32 acc = StackItem.unwrap(inputs[0]);
        for (uint256 i = 1; i < inputs.length; i++) {
            acc = acc & StackItem.unwrap(inputs[i]);
        }

        StackItem[] memory outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(acc);
        return outputs;
    }
}
