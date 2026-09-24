// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OperandV2, StackItem} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {Pointer} from "rain-solmem-0.1.28/src/lib/LibPointer.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {Float, LibDecimalFloat} from "rain-math-float-0.2.1/src/lib/LibDecimalFloat.sol";
import {
    LibDecimalFloatImplementation
} from "rain-math-float-0.2.1/src/lib/implementation/LibDecimalFloatImplementation.sol";

/// @title LibOpAgree
/// @notice Opcode to return 1 if the highest and lowest of the values are no
/// more than a proportional tolerance apart, else 0.
///
/// The first input is the tolerance, as a fraction, and every subsequent input
/// is a value. The proportion is relative to the LOWER value, so a tolerance of
/// `0.01` means the highest value cannot be more than 1% larger than the
/// lowest. The check is `highest - lowest <= tolerance * abs(lowest)`.
///
/// The magnitude of the lowest value is what the proportion is taken of. For
/// the non-negative values this word exists for (prices) that is exactly "1%
/// larger than the lowest". It also keeps the word sane for negative values,
/// where taking 1% of a negative number would reject values that are identical
/// to each other.
///
/// The magnitude is taken on the unpacked coefficient rather than with
/// `Float.abs`. An unpacked coefficient is an int224 widened to an int256, so
/// negating it is always exact, where `Float.abs` has to pack the magnitude
/// back into an int224 and so raises the exponent for the most negative
/// coefficient, reverting with `ExponentOverflow` when the exponent is already
/// at its maximum. `min-negative-value()` is a representable value and an
/// `ensure` guard reading it should answer 0, not revert.
///
/// `agree-absolute` is the absolute variant of the same check.
///
/// ROUNDING. The spread is compared against the limit at full internal
/// precision, i.e. neither is packed back into a `Float`, so the only places a
/// value can be lost are the subtraction and the multiplication.
/// - The multiplication truncates the product's magnitude toward zero, and the
///   limit is non-negative whenever the tolerance is, so the limit can only
///   come out smaller, i.e. only ever rounds toward rejecting.
/// - The subtraction truncates the operand with the smaller exponent toward
///   zero. For values that share a sign - the domain this word exists for -
///   the operands of `highest + (-lowest)` have opposite signs, so shrinking
///   one of them can only make the spread larger, which again only ever rounds
///   toward rejecting. Where the values straddle zero the two operands share a
///   sign and the truncation goes the other way, by at most one unit in the
///   last of ~76 significant digits.
library LibOpAgree {
    using LibDecimalFloat for Float;

    /// @notice `agree` integrity check. Requires at least 3 inputs (a
    /// tolerance and two values) and produces 1 output. A single value
    /// trivially agrees with itself, which is a vacuous guard, so two values
    /// is the minimum.
    /// @param operand Low 4 bits of the high byte encode the input count.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2 operand) internal pure returns (uint256, uint256) {
        // A tolerance and at least two values.
        uint256 inputs = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;
        inputs = inputs > 2 ? inputs : 3;
        return (inputs, 1);
    }

    /// @notice AGREE
    /// 1 if `highest - lowest <= tolerance * abs(lowest)`, else 0.
    /// @param operand Low 4 bits of the high byte encode the input count.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2 operand, Pointer stackTop) internal pure returns (Pointer) {
        unchecked {
            uint256 inputs = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;
            Pointer end = Pointer.wrap(Pointer.unwrap(stackTop) + (inputs * 0x20));

            Float tolerance;
            Float lowest;
            assembly ("memory-safe") {
                tolerance := mload(stackTop)
                lowest := mload(add(stackTop, 0x20))
            }
            Float highest = lowest;

            Pointer cursor = Pointer.wrap(Pointer.unwrap(stackTop) + 0x40);
            while (Pointer.unwrap(cursor) < Pointer.unwrap(end)) {
                Float value;
                assembly ("memory-safe") {
                    value := mload(cursor)
                }
                // Strict comparisons keep the first representation seen when
                // two values are numerically equal, which is what the
                // reference implementation does. Numerically equal values can
                // be packed differently and the packing feeds the rounding of
                // the limit, so the tie break has to be the same in both.
                if (value.lt(lowest)) {
                    lowest = value;
                }
                if (value.gt(highest)) {
                    highest = value;
                }
                cursor = Pointer.wrap(Pointer.unwrap(cursor) + 0x20);
            }

            bool agreed;
            {
                (int256 lowestCoefficient, int256 lowestExponent) = lowest.unpack();

                int256 spreadCoefficient;
                int256 spreadExponent;
                {
                    (int256 highestCoefficient, int256 highestExponent) = highest.unpack();
                    (spreadCoefficient, spreadExponent) = LibDecimalFloatImplementation.sub(
                        highestCoefficient, highestExponent, lowestCoefficient, lowestExponent
                    );
                }

                int256 limitCoefficient;
                int256 limitExponent;
                {
                    (int256 toleranceCoefficient, int256 toleranceExponent) = tolerance.unpack();
                    (limitCoefficient, limitExponent) = LibDecimalFloatImplementation.mul(
                        toleranceCoefficient,
                        toleranceExponent,
                        lowestCoefficient < 0 ? -lowestCoefficient : lowestCoefficient,
                        lowestExponent
                    );
                }

                (int256 rescaledSpread, int256 rescaledLimit) = LibDecimalFloatImplementation.compareRescale(
                    spreadCoefficient, spreadExponent, limitCoefficient, limitExponent
                );
                agreed = rescaledSpread <= rescaledLimit;
            }

            stackTop = Pointer.wrap(Pointer.unwrap(end) - 0x20);
            assembly ("memory-safe") {
                mstore(stackTop, agreed)
            }
        }
        return stackTop;
    }

    /// @notice Gas intensive reference implementation of AGREE for testing.
    /// @param inputs The input values from the stack.
    /// @return outputs The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory outputs)
    {
        Float lowest = Float.wrap(StackItem.unwrap(inputs[1]));
        Float highest = lowest;
        for (uint256 i = 2; i < inputs.length; i++) {
            Float value = Float.wrap(StackItem.unwrap(inputs[i]));
            if (value.lt(lowest)) {
                lowest = value;
            }
            if (value.gt(highest)) {
                highest = value;
            }
        }

        // The intermediates are scoped so that the coefficient and exponent
        // pairs do not all have to be live at once, which does not fit on the
        // stack.
        bool agreed;
        {
            (int256 lowestCoefficient, int256 lowestExponent) = lowest.unpack();

            int256 spreadCoefficient;
            int256 spreadExponent;
            {
                (int256 highestCoefficient, int256 highestExponent) = highest.unpack();
                (spreadCoefficient, spreadExponent) = LibDecimalFloatImplementation.sub(
                    highestCoefficient, highestExponent, lowestCoefficient, lowestExponent
                );
            }

            int256 limitCoefficient;
            int256 limitExponent;
            {
                (int256 toleranceCoefficient, int256 toleranceExponent) =
                    Float.wrap(StackItem.unwrap(inputs[0])).unpack();
                (limitCoefficient, limitExponent) = LibDecimalFloatImplementation.mul(
                    toleranceCoefficient,
                    toleranceExponent,
                    lowestCoefficient < 0 ? -lowestCoefficient : lowestCoefficient,
                    lowestExponent
                );
            }

            (int256 rescaledSpread, int256 rescaledLimit) = LibDecimalFloatImplementation.compareRescale(
                spreadCoefficient, spreadExponent, limitCoefficient, limitExponent
            );
            agreed = rescaledSpread <= rescaledLimit;
        }

        outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(bytes32(uint256(agreed ? 1 : 0)));
    }
}
