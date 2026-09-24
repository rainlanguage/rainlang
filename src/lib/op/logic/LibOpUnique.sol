// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OperandV2, StackItem} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {Pointer} from "rain-solmem-0.1.28/src/lib/LibPointer.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {Float, LibDecimalFloat} from "rain-math-float-0.2.1/src/lib/LibDecimalFloat.sol";

/// @title LibOpUnique
/// @notice Opcode to return 1 if every input is distinct from every other
/// input, else 0.
///
/// The matched pair of `equal-to`: `equal-to` asserts every input is the same,
/// `unique` asserts every input differs. Both are variadic and both are
/// intended as `ensure` predicates.
///
/// Distinctness is numerical, the same equality `equal-to` uses, so `1` and
/// `1.0` are NOT unique with respect to each other.
library LibOpUnique {
    using LibDecimalFloat for Float;

    /// @notice `unique` integrity check. Requires at least 2 inputs and
    /// produces 1 output. A single value is trivially unique, which is a
    /// vacuous guard, so the minimum is 2.
    /// @param operand Low 4 bits of the high byte encode the input count.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2 operand) internal pure returns (uint256, uint256) {
        // There must be at least two inputs.
        uint256 inputs = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;
        inputs = inputs > 1 ? inputs : 2;
        return (inputs, 1);
    }

    /// @notice UNIQUE
    /// 1 if no two inputs are numerically equal, else 0.
    /// @param operand Low 4 bits of the high byte encode the input count.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2 operand, Pointer stackTop) internal pure returns (Pointer) {
        unchecked {
            uint256 inputs = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;
            Pointer end = Pointer.wrap(Pointer.unwrap(stackTop) + (inputs * 0x20));

            bool unique = true;
            Pointer aCursor = stackTop;
            while (Pointer.unwrap(aCursor) < Pointer.unwrap(end)) {
                Float a;
                assembly ("memory-safe") {
                    a := mload(aCursor)
                }

                Pointer bCursor = Pointer.wrap(Pointer.unwrap(aCursor) + 0x20);
                while (Pointer.unwrap(bCursor) < Pointer.unwrap(end)) {
                    Float b;
                    assembly ("memory-safe") {
                        b := mload(bCursor)
                    }
                    if (a.eq(b)) {
                        unique = false;
                        break;
                    }
                    bCursor = Pointer.wrap(Pointer.unwrap(bCursor) + 0x20);
                }

                if (!unique) {
                    break;
                }

                aCursor = Pointer.wrap(Pointer.unwrap(aCursor) + 0x20);
            }

            stackTop = Pointer.wrap(Pointer.unwrap(end) - 0x20);
            assembly ("memory-safe") {
                mstore(stackTop, unique)
            }
        }
        return stackTop;
    }

    /// @notice Gas intensive reference implementation of UNIQUE for testing.
    /// @param inputs The input values from the stack.
    /// @return outputs The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory outputs)
    {
        bool unique = true;
        for (uint256 i = 0; i < inputs.length; i++) {
            for (uint256 j = 0; j < inputs.length; j++) {
                if (i == j) {
                    continue;
                }
                if (Float.wrap(StackItem.unwrap(inputs[i])).eq(Float.wrap(StackItem.unwrap(inputs[j])))) {
                    unique = false;
                }
            }
        }

        outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(bytes32(uint256(unique ? 1 : 0)));
    }
}
