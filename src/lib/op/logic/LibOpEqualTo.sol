// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OperandV2, StackItem} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {Pointer} from "rain-solmem-0.1.28/src/lib/LibPointer.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {LibDecimalFloat, Float} from "rain-math-float-0.2.1/src/lib/LibDecimalFloat.sol";

/// @title LibOpEqualTo
/// @notice Opcode to return 1 if every item on the stack up to the inputs limit
/// is equal to the next, else 0. Equality is defined as decimal float equality,
/// so 1.0 == 1 etc. Two inputs is the binary case, `equal-to(a b)`, and more
/// than two inputs is the variadic case, `equal-to(a b c)`, which holds when
/// `a == b` and `b == c`.
library LibOpEqualTo {
    using LibDecimalFloat for Float;

    /// @notice `equal-to` integrity check. Requires at least 2 inputs and
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

    /// @notice Float equality
    /// Float equality is 1 if every input is equal to the input after it, else
    /// 0. Equality is defined as decimal float equality.
    /// @param operand Low 4 bits of the high byte encode the input count.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2 operand, Pointer stackTop) internal pure returns (Pointer) {
        unchecked {
            uint256 length = 0x20 * (uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F);
            Pointer cursor = stackTop;
            Pointer end = Pointer.wrap(Pointer.unwrap(stackTop) + length);
            stackTop = Pointer.wrap(Pointer.unwrap(end) - 0x20);

            Float a;
            assembly ("memory-safe") {
                a := mload(cursor)
            }
            cursor = Pointer.wrap(Pointer.unwrap(cursor) + 0x20);

            bool areEqual = true;
            while (Pointer.unwrap(cursor) < Pointer.unwrap(end)) {
                Float b;
                assembly ("memory-safe") {
                    b := mload(cursor)
                }
                areEqual = a.eq(b);
                if (!areEqual) {
                    break;
                }
                a = b;
                cursor = Pointer.wrap(Pointer.unwrap(cursor) + 0x20);
            }

            assembly ("memory-safe") {
                mstore(stackTop, areEqual)
            }

            return stackTop;
        }
    }

    /// @notice Gas intensive reference implementation of float equal for testing.
    /// @param inputs The input values from the stack.
    /// @return outputs The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory outputs)
    {
        bool areEqual = true;
        for (uint256 i = 1; i < inputs.length; i++) {
            Float a = Float.wrap(StackItem.unwrap(inputs[i - 1]));
            Float b = Float.wrap(StackItem.unwrap(inputs[i]));
            areEqual = a.eq(b);
            if (!areEqual) {
                break;
            }
        }

        outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(bytes32(uint256(areEqual ? 1 : 0)));
    }
}
