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
import {AgreeToleranceNegative, AgreeNoPositiveTolerance} from "../../../error/ErrEval.sol";

/// @title LibOpAgree
/// @notice Opcode to return 1 if the highest and lowest of the values are no
/// further apart than a tolerance drawn from two terms, else 0.
///
/// The first input is an ABSOLUTE tolerance, the second is a PROPORTIONAL one,
/// and every subsequent input is a value. The check is
/// `highest - lowest <= max(absolute, proportional * max(abs(value)))`.
///
/// BOTH TOLERANCES ARE ALWAYS GIVEN, neither defaults. A proportional
/// tolerance alone breaks as the values approach zero, because a proportion of
/// a near-zero quantity is not meaningful: values of `-0.001` and `0.001` read
/// as 200% apart while agreeing by any practical measure, and no anchor drawn
/// from the values themselves avoids it, because every such anchor shrinks
/// toward zero at the rate that makes the ratio diverge. An absolute tolerance
/// alone does not scale with the values. Taking whichever of the two is larger
/// covers the whole domain: the absolute term carries the region near zero,
/// the proportional term carries the rest.
///
/// This is the form Python's `math.isclose` (PEP 485) and Julia's `isapprox`
/// use. `numpy.isclose` instead SUMS the two terms, which PEP 485 rejects
/// because "if the absolute and relative tolerances are of similar magnitude,
/// then the allowed difference will be about twice as large as expected".
/// Here the sum is rejected for a second reason on top of that one: it is the
/// more permissive of the two, and this word is a guard that rounds toward
/// rejecting.
///
/// Requiring both means an expression that wants only one writes the other as
/// zero, asserting that choice rather than inheriting it. A silently defaulted
/// absolute tolerance of zero is exactly the guard that looks correct and
/// breaks near zero.
///
/// NEITHER TOLERANCE MAY BE NEGATIVE, and AT LEAST ONE MUST BE POSITIVE. See
/// `validateTolerances` for why each is rejected rather than given a meaning.
/// Either one alone may be zero, which is how an expression asks for only the
/// other.
///
/// THE ANCHOR is the largest magnitude among the values, taken once across the
/// whole list rather than per pair. That is what makes a single
/// highest-to-lowest check equivalent to checking every pair: the spread is
/// the largest pairwise difference, so bounding it bounds all of them. A
/// per-pair anchor would give one limit per pair, which no single spread
/// summarises.
///
/// Magnitudes are taken on the unpacked coefficient rather than with
/// `Float.abs`. An unpacked coefficient is an int224 widened to an int256, so
/// negating it is always exact, where `Float.abs` has to pack the magnitude
/// back into an int224 and so raises the exponent for the most negative
/// coefficient, reverting `ExponentOverflow` when the exponent is already at
/// its maximum. `min-negative-value()` is a representable value and an
/// `ensure` guard reading it should answer 0, not revert.
///
/// ROUNDING. The spread is compared against the limit at full internal
/// precision, i.e. neither is packed back into a `Float`, so the only places a
/// value can be lost are the subtraction and the multiplication. Selecting the
/// larger of two terms is exact, so taking the max rather than the sum removes
/// a lossy operation rather than adding one.
/// - The multiplication truncates the product's magnitude toward zero. The
///   anchor is a magnitude and so non-negative, and the proportional tolerance
///   is non-negative because `validateTolerances` has rejected anything else,
///   so the term can only come out smaller: it only ever rounds toward
///   rejecting. That is a guarantee rather than an assumption about sane use.
/// - The subtraction truncates the operand with the smaller exponent toward
///   zero. `highest + (-lowest)` has opposite-signed operands whenever the
///   values share a sign, so shrinking one can only widen the spread, which
///   again rounds toward rejecting. Where the values straddle zero the two
///   operands share a sign and the truncation goes the other way, by at most
///   one unit in the last of ~76 significant digits.
library LibOpAgree {
    using LibDecimalFloat for Float;

    /// @notice `agree` integrity check. Requires at least 4 inputs (two
    /// tolerances and two values) and produces 1 output. A single value
    /// trivially agrees with itself, which is a guard that passes on nothing,
    /// so two values is the minimum.
    /// @param operand Low 4 bits of the high byte encode the input count.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2 operand) internal pure returns (uint256, uint256) {
        // Two tolerances and at least two values.
        uint256 inputs = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;
        inputs = inputs > 3 ? inputs : 4;
        return (inputs, 1);
    }

    /// @notice AGREE
    /// 1 if `highest - lowest <= max(absolute, proportional * max(abs(value)))`,
    /// else 0.
    /// @param operand Low 4 bits of the high byte encode the input count.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2 operand, Pointer stackTop) internal pure returns (Pointer) {
        unchecked {
            uint256 inputs = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;
            Pointer end = Pointer.wrap(Pointer.unwrap(stackTop) + (inputs * 0x20));

            Float absolute;
            Float proportional;
            Float lowest;
            assembly ("memory-safe") {
                absolute := mload(stackTop)
                proportional := mload(add(stackTop, 0x20))
                lowest := mload(add(stackTop, 0x40))
            }
            Float highest = lowest;

            Pointer cursor = Pointer.wrap(Pointer.unwrap(stackTop) + 0x60);
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

            bool agreed = agreedAt(absolute, proportional, lowest, highest);

            stackTop = Pointer.wrap(Pointer.unwrap(end) - 0x20);
            assembly ("memory-safe") {
                mstore(stackTop, agreed)
            }
        }
        return stackTop;
    }

    /// @notice The distance between the two extremes, as an unpacked
    /// coefficient and exponent.
    /// @param lowest The lowest value.
    /// @param highest The highest value.
    /// @return The spread's coefficient.
    /// @return The spread's exponent.
    function spreadOf(Float lowest, Float highest) internal pure returns (int256, int256) {
        (int256 lowestCoefficient, int256 lowestExponent) = lowest.unpack();
        (int256 highestCoefficient, int256 highestExponent) = highest.unpack();
        // Destructured rather than returned directly because slither reads
        // `return f(...)` on a tuple-returning call as an ignored return value.
        (int256 spreadCoefficient, int256 spreadExponent) =
            LibDecimalFloatImplementation.sub(highestCoefficient, highestExponent, lowestCoefficient, lowestExponent);
        return (spreadCoefficient, spreadExponent);
    }

    /// @notice The quantity the proportional tolerance is taken of: whichever
    /// of the two extremes has the larger magnitude. Every other value lies
    /// between them, so no value in the list has a magnitude exceeding both,
    /// which is what makes this the largest magnitude in the whole list
    /// without walking it again.
    /// @param lowest The lowest value.
    /// @param highest The highest value.
    /// @return The anchor's coefficient, always non-negative.
    /// @return The anchor's exponent.
    function anchorOf(Float lowest, Float highest) internal pure returns (int256, int256) {
        (int256 lowestMagnitude, int256 lowestExponent) = lowest.unpack();
        (int256 highestMagnitude, int256 highestExponent) = highest.unpack();
        lowestMagnitude = lowestMagnitude < 0 ? -lowestMagnitude : lowestMagnitude;
        highestMagnitude = highestMagnitude < 0 ? -highestMagnitude : highestMagnitude;
        (int256 rescaledLowest, int256 rescaledHighest) = LibDecimalFloatImplementation.compareRescale(
            lowestMagnitude, lowestExponent, highestMagnitude, highestExponent
        );
        return
            rescaledLowest >= rescaledHighest ? (lowestMagnitude, lowestExponent) : (highestMagnitude, highestExponent);
    }

    /// @notice The tolerance the spread is checked against: whichever of the
    /// two terms is LARGER, `max(absolute, proportional * anchor)`.
    ///
    /// Taking the larger rather than the sum is what keeps the word rounding
    /// toward rejecting. For non-negative terms `max(a, b) <= a + b`, with
    /// equality only when one of them is zero, so the sum accepts everything
    /// the max accepts and more — up to twice as much where the two terms are
    /// of similar size. An expression that sets only one tolerance gets the
    /// same answer either way, because the other term is zero.
    ///
    /// Both terms are known non-negative here, and not both zero, because
    /// `validateTolerances` has already rejected anything else. That is what
    /// makes taking the larger safe: without it, a negative tolerance would be
    /// silently dominated by the other term and the guard would pass as though
    /// it were well formed.
    /// @param absolute The absolute tolerance.
    /// @param proportional The proportional tolerance.
    /// @param lowest The lowest value.
    /// @param highest The highest value.
    /// @return The limit's coefficient.
    /// @return The limit's exponent.
    function limitOf(Float absolute, Float proportional, Float lowest, Float highest)
        internal
        pure
        returns (int256, int256)
    {
        int256 scaledCoefficient;
        int256 scaledExponent;
        {
            (int256 anchorCoefficient, int256 anchorExponent) = anchorOf(lowest, highest);
            (int256 proportionalCoefficient, int256 proportionalExponent) = proportional.unpack();
            (scaledCoefficient, scaledExponent) = LibDecimalFloatImplementation.mul(
                proportionalCoefficient, proportionalExponent, anchorCoefficient, anchorExponent
            );
        }
        (int256 absoluteCoefficient, int256 absoluteExponent) = absolute.unpack();
        (int256 rescaledAbsolute, int256 rescaledScaled) = LibDecimalFloatImplementation.compareRescale(
            absoluteCoefficient, absoluteExponent, scaledCoefficient, scaledExponent
        );
        return rescaledAbsolute >= rescaledScaled
            ? (absoluteCoefficient, absoluteExponent)
            : (scaledCoefficient, scaledExponent);
    }

    /// @notice Rejects tolerances that do not describe a tolerance at all.
    ///
    /// A NEGATIVE tolerance is meaningless rather than strict: the spread is a
    /// distance, so it is never negative, and nothing a caller could want is
    /// expressed by one. It is representable only because floats are signed.
    /// Accepting it is worse than useless here, because the limit is the
    /// larger of the two terms, so a negative tolerance is simply dominated by
    /// the other one and the guard passes as though it were well formed. A
    /// guard that silently succeeds on malformed input is the one outcome a
    /// guard must not have.
    ///
    /// AT LEAST ONE TOLERANCE MUST BE POSITIVE. If neither is, there is no
    /// tolerance at all: the limit is zero and the word becomes an exact
    /// equality check, which is what the variadic `equal-to` is for. So it
    /// means the wrong word was reached for rather than that a tolerance of
    /// nothing was wanted. Either tolerance ALONE may be zero; that is how an
    /// expression asks for only the other one.
    ///
    /// The positive test is `neither is greater than zero` rather than `both
    /// are zero`, so that it states the invariant on its own terms rather than
    /// naming one case that violates it, and stays correct if the negative
    /// check above is ever moved or removed.
    ///
    /// Both tests compare against a zero `Float` rather than unpacking, so the
    /// comparisons are numerical and every representation of zero — `0`,
    /// `0e0`, `0.0` — is treated alike. Unpacking and reading only the
    /// coefficient would be equivalent, since a float's sign and zero-ness
    /// live entirely there, but it discards the exponent and slither reads a
    /// partly ignored tuple return as `unused-return`.
    /// @param absolute The absolute tolerance.
    /// @param proportional The proportional tolerance.
    function validateTolerances(Float absolute, Float proportional) internal pure {
        Float zero = LibDecimalFloat.packLossless(0, 0);
        if (absolute.lt(zero) || proportional.lt(zero)) {
            revert AgreeToleranceNegative();
        }
        if (!absolute.gt(zero) && !proportional.gt(zero)) {
            revert AgreeNoPositiveTolerance();
        }
    }

    /// @notice The comparison, shared by `run` and `referenceFn` so the two
    /// cannot drift apart on the arithmetic. What differs between them, and so
    /// what the reference check actually exercises, is how the highest and
    /// lowest are found: a pointer walk against an array walk. The arithmetic
    /// is pinned by the eval assertions instead, which derive their boundaries
    /// rather than observing them.
    /// @param absolute The absolute tolerance.
    /// @param proportional The proportional tolerance.
    /// @param lowest The lowest value.
    /// @param highest The highest value.
    /// @return Whether the spread is within the tolerance.
    function agreedAt(Float absolute, Float proportional, Float lowest, Float highest) internal pure returns (bool) {
        validateTolerances(absolute, proportional);
        (int256 spreadCoefficient, int256 spreadExponent) = spreadOf(lowest, highest);
        (int256 limitCoefficient, int256 limitExponent) = limitOf(absolute, proportional, lowest, highest);
        (int256 rescaledSpread, int256 rescaledLimit) = LibDecimalFloatImplementation.compareRescale(
            spreadCoefficient, spreadExponent, limitCoefficient, limitExponent
        );
        return rescaledSpread <= rescaledLimit;
    }

    /// @notice Gas intensive reference implementation of AGREE for testing.
    /// @param inputs The input values from the stack.
    /// @return outputs The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory outputs)
    {
        Float lowest = Float.wrap(StackItem.unwrap(inputs[2]));
        Float highest = lowest;
        for (uint256 i = 3; i < inputs.length; i++) {
            Float value = Float.wrap(StackItem.unwrap(inputs[i]));
            if (value.lt(lowest)) {
                lowest = value;
            }
            if (value.gt(highest)) {
                highest = value;
            }
        }

        bool agreed =
            agreedAt(Float.wrap(StackItem.unwrap(inputs[0])), Float.wrap(StackItem.unwrap(inputs[1])), lowest, highest);

        outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(bytes32(uint256(agreed ? 1 : 0)));
    }
}
