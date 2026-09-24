// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OperandV2, StackItem} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {Pointer} from "rain-solmem-0.1.28/src/lib/LibPointer.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {Float, LibDecimalFloat} from "rain-math-float-0.2.1/src/lib/LibDecimalFloat.sol";
import {InNeedlesZero} from "../../../error/ErrIntegrity.sol";

/// @title LibOpIn
/// @notice Opcode to return 1 if every needle is a member of the set built from
/// the remaining inputs, else 0.
///
/// The operand is the number of needles. The first that many inputs are the
/// needles and every subsequent input is a member of the set they must all be
/// in. There is exactly one set, so a single call answers "are all of these
/// values in this list".
///
/// Membership is numerical equality, the same equality `equal-to` uses, so
/// `1.0` is in `(1)`. Use `binary-equal-to` style comparisons directly if
/// binary equality is wanted instead.
library LibOpIn {
    using LibDecimalFloat for Float;

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
            revert InNeedlesZero();
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

    /// @notice IN
    /// 1 if every needle is numerically equal to at least one set member, else
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
                Float needle;
                assembly ("memory-safe") {
                    needle := mload(needleCursor)
                }

                bool found = false;
                Pointer setCursor = setStart;
                while (Pointer.unwrap(setCursor) < Pointer.unwrap(end)) {
                    Float member;
                    assembly ("memory-safe") {
                        member := mload(setCursor)
                    }
                    if (needle.eq(member)) {
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

    /// @notice Gas intensive reference implementation of IN for testing.
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
            Float needle = Float.wrap(StackItem.unwrap(inputs[i]));
            bool found = false;
            for (uint256 j = needles; j < inputs.length; j++) {
                if (needle.eq(Float.wrap(StackItem.unwrap(inputs[j])))) {
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
