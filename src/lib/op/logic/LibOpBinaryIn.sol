// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OperandV2, StackItem} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {Pointer} from "rain-solmem-0.1.28/src/lib/LibPointer.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {BinaryInNeedlesZero} from "../../../error/ErrIntegrity.sol";

/// @title LibOpBinaryIn
/// @notice Opcode to return 1 if every needle is a member of the set built from
/// the remaining inputs, else 0.
///
/// The operand is the number of needles. The first that many inputs are the
/// needles and every subsequent input is a member of the set they must all be
/// in. There is exactly one set, so a single call answers "are all of these
/// values in this list".
///
/// THE OPERAND DEFAULTS TO ONE NEEDLE, so `binary-in(x a b c)` asks whether
/// `x` is in `(a b c)`. An explicit zero is NOT a way of writing one: it
/// still reaches the integrity check and reverts, because zero needles is a
/// check that passes on nothing.
///
/// THE NEEDLE COUNT IS CAPPED AT 14 in practice. The operand field holds a
/// uint16, but an opcode takes at most 15 inputs, and the set needs at least
/// one of them. A larger count asks for more inputs than an opcode can carry
/// and is reported as `BadOpInputsLength` at deploy time, naming the input
/// count it would have needed.
///
/// MEMBERSHIP IS BINARY EQUALITY, the same equality `binary-equal-to` uses:
/// the words are compared bit for bit and nothing is interpreted as a number.
///
/// That is what makes this word safe for the job it exists for, which is
/// asking whether an IDENTITY — a signer, a token symbol — is in an
/// allowlist. Numerical equality would decode each word as a `Float` and
/// compare the values, and two distinct identities can decode to the same
/// value: a coefficient and exponent of `(100, 0)` is numerically equal to
/// `(10, 1)` while being a different word. An allowlist checked that way can
/// be satisfied by something that was never on it, so membership of a set of
/// identities has to be bit for bit.
///
/// Use it on quantities only where bitwise identity is genuinely what is
/// wanted, since two numerically equal quantities can be packed differently
/// and will NOT match here.
library LibOpBinaryIn {
    /// @notice `in` integrity check. The low 16 bits of the operand are the
    /// number of needles, which must be at least 1. There must be at least one
    /// more input than there are needles, so that the set is not empty.
    /// @param operand Low 16 bits encode the needle count, low 4 bits of the
    /// high byte encode the input count.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2 operand) internal pure returns (uint256, uint256) {
        uint256 needles = uint256(OperandV2.unwrap(operand)) & 0xFFFF;
        // Zero needles would make the check vacuously true, which is never what
        // an `ensure` guard wants, so it is rejected at deploy time rather than
        // silently passing at runtime.
        if (needles == 0) {
            revert BinaryInNeedlesZero();
        }
        uint256 inputs = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;
        // Every needle plus at least one set member. Reporting the minimum when
        // the bytecode declares fewer is what surfaces the mistake as a
        // `BadOpInputsLength` at deploy time.
        // `needles` is at most `type(uint16).max` so this cannot overflow.
        unchecked {
            inputs = inputs > needles ? inputs : needles + 1;
        }
        return (inputs, 1);
    }

    /// @notice BINARY IN
    /// 1 if every needle is bitwise identical to at least one set member, else
    /// 0.
    /// @param operand Low 16 bits encode the needle count, low 4 bits of the
    /// high byte encode the input count.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2 operand, Pointer stackTop) internal pure returns (Pointer) {
        unchecked {
            uint256 inputs = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;
            uint256 needles = uint256(OperandV2.unwrap(operand)) & 0xFFFF;

            Pointer setStart = Pointer.wrap(Pointer.unwrap(stackTop) + (needles * 0x20));
            Pointer end = Pointer.wrap(Pointer.unwrap(stackTop) + (inputs * 0x20));

            bool allIn = true;
            Pointer needleCursor = stackTop;
            while (Pointer.unwrap(needleCursor) < Pointer.unwrap(setStart)) {
                bytes32 needle;
                assembly ("memory-safe") {
                    needle := mload(needleCursor)
                }

                bool found = false;
                Pointer setCursor = setStart;
                while (Pointer.unwrap(setCursor) < Pointer.unwrap(end)) {
                    bytes32 member;
                    assembly ("memory-safe") {
                        member := mload(setCursor)
                    }
                    if (needle == member) {
                        found = true;
                        break;
                    }
                    setCursor = Pointer.wrap(Pointer.unwrap(setCursor) + 0x20);
                }

                if (!found) {
                    allIn = false;
                    break;
                }

                needleCursor = Pointer.wrap(Pointer.unwrap(needleCursor) + 0x20);
            }

            stackTop = Pointer.wrap(Pointer.unwrap(end) - 0x20);
            assembly ("memory-safe") {
                mstore(stackTop, allIn)
            }
        }
        return stackTop;
    }

    /// @notice Gas intensive reference implementation of BINARY IN for
    /// testing.
    /// @param operand Low 16 bits encode the needle count.
    /// @param inputs The input values from the stack.
    /// @return outputs The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2 operand, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory outputs)
    {
        uint256 needles = uint256(OperandV2.unwrap(operand)) & 0xFFFF;

        bool allIn = true;
        for (uint256 i = 0; i < needles; i++) {
            bytes32 needle = StackItem.unwrap(inputs[i]);
            bool found = false;
            for (uint256 j = needles; j < inputs.length; j++) {
                if (needle == StackItem.unwrap(inputs[j])) {
                    found = true;
                }
            }
            if (!found) {
                allIn = false;
            }
        }

        outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(bytes32(uint256(allIn ? 1 : 0)));
    }
}
