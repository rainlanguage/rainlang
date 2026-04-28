// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {Float, LibDecimalFloat} from "rain.math.float/lib/LibDecimalFloat.sol";

/// @title LibOpAny
/// @notice Opcode to return the first nonzero item on the stack up to the inputs
/// limit.
library LibOpAny {
    using LibDecimalFloat for Float;

    /// @notice `any` integrity check. Requires at least 1 input and produces 1 output.
    /// @param operand The operand encoding the number of inputs.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2 operand) internal pure returns (uint256, uint256) {
        // There must be at least one input.
        uint256 inputs = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;
        inputs = inputs > 0 ? inputs : 1;
        return (inputs, 1);
    }

    /// @notice ANY
    /// ANY is the first nonzero item, else 0.
    /// @param operand The operand encoding the number of inputs.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2 operand, Pointer stackTop) internal pure returns (Pointer) {
        unchecked {
            uint256 length = 0x20 * (uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F);
            Float item;
            Pointer cursor = stackTop;
            Pointer end = Pointer.wrap(Pointer.unwrap(stackTop) + length);
            stackTop = Pointer.wrap(Pointer.unwrap(end) - 0x20);
            while (Pointer.unwrap(cursor) < Pointer.unwrap(end)) {
                assembly ("memory-safe") {
                    item := mload(cursor)
                }
                if (!item.isZero()) {
                    assembly ("memory-safe") {
                        mstore(stackTop, item)
                    }
                    break;
                }

                cursor = Pointer.wrap(Pointer.unwrap(cursor) + 0x20);
            }
        }
        return stackTop;
    }

    /// @notice Gas intensive reference implementation of ANY for testing.
    /// @param inputs The input values from the stack.
    /// @return outputs The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory outputs)
    {
        // Zero length inputs is not supported so this 0 will always be written
        // over.
        Float value = Float.wrap(0);
        for (uint256 i = 0; i < inputs.length; i++) {
            value = Float.wrap(StackItem.unwrap(inputs[i]));
            if (!value.isZero()) {
                break;
            }
        }
        outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(Float.unwrap(value));
    }
}
