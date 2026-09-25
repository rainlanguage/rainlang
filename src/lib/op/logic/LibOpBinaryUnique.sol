// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OperandV2, StackItem} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {Pointer} from "rain-solmem-0.1.28/src/lib/LibPointer.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";

/// @title LibOpBinaryUnique
/// @notice Opcode to return 1 if every input is distinct from every other
/// input, else 0.
///
/// The matched pair of `binary-equal-to`: that word asserts every input is the
/// same, this one asserts every input differs. Both are variadic and both are
/// intended as `ensure` predicates.
///
/// DISTINCTNESS IS BINARY, the same equality `binary-equal-to` uses: the words
/// are compared bit for bit and nothing is interpreted as a number.
///
/// That is what makes this word safe for the job it exists for, which is
/// asserting that a set of IDENTITIES — signers filling distinct seats — has
/// no repeats. Numerical equality would decode each word as a `Float`, and two
/// distinct identities can decode to the same value: a coefficient and
/// exponent of `(100, 0)` is numerically equal to `(10, 1)` while being a
/// different word. A uniqueness check that way can REJECT two distinct
/// identities as duplicates, and one that way over a differently packed set
/// can ACCEPT the same identity twice, so distinctness of identities has to be
/// bit for bit.
///
/// Use it on quantities only where bitwise identity is genuinely what is
/// wanted, since `1` and `1.0` are numerically equal but distinct here.
library LibOpBinaryUnique {
    /// @notice `binary-unique` integrity check. Requires at least 2 inputs and
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

    /// @notice BINARY UNIQUE
    /// 1 if no two inputs are bitwise identical, else 0.
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
                bytes32 a;
                assembly ("memory-safe") {
                    a := mload(aCursor)
                }

                Pointer bCursor = Pointer.wrap(Pointer.unwrap(aCursor) + 0x20);
                while (Pointer.unwrap(bCursor) < Pointer.unwrap(end)) {
                    bytes32 b;
                    assembly ("memory-safe") {
                        b := mload(bCursor)
                    }
                    if (a == b) {
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

    /// @notice Gas intensive reference implementation of BINARY UNIQUE for
    /// testing.
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
                if (StackItem.unwrap(inputs[i]) == StackItem.unwrap(inputs[j])) {
                    unique = false;
                }
            }
        }

        outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(bytes32(uint256(unique ? 1 : 0)));
    }
}
