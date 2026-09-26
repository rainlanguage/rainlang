// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OperandV2, StackItem} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {Pointer} from "rain-solmem-0.1.28/src/lib/LibPointer.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {Float, LibDecimalFloat} from "rain-math-float-0.2.3/src/lib/LibDecimalFloat.sol";
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
/// The same form as `math.isclose` (PEP 485) and Julia's `isapprox`.
/// `numpy.isclose` sums the two terms instead.
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
/// THE ARITHMETIC IS `LibDecimalFloat.agree`, not this word. This word finds
/// the extremes and validates the tolerances; the comparison itself lives in
/// the float library, which is where its tests, its mutation coverage and its
/// precision contract live too.
///
/// It belongs there because it cannot be composed from the float library's
/// public surface. That surface reverts `ExponentOverflow` rather than
/// truncating an exponent, and both `abs` and `sub` do so at the extremes of
/// the range: `min-negative-value()` is a representable value and an `ensure`
/// guard reading it should answer 0, not revert. `agree` works below that
/// surface and never packs the spread back, which an opcode cannot do without
/// reaching into the library's internals.
///
/// PRECISION is documented on `LibDecimalFloat.agree`, including the one case
/// where it answers differently from an exact comparison: a spread landing
/// exactly on the limit whose low digits were discarded by the subtraction. The
/// excess admitted there is under `1e-76` of the spread's own magnitude.
///
/// NO ROUNDING DIRECTION IS PROMISED, deliberately. A direction matters where
/// error accumulates — the leaky bucket this feeds is touched by every mint,
/// so a consistent bias there compounds. Nothing accumulates here: `agree`
/// answers 0 or 1 into an `ensure`. Biasing that answer would require placing
/// the spread within an ulp at ~76 digits of the limit, which means
/// controlling independently signed attestations to that precision, and the
/// limit is a policy number the mint admin chose with orders of magnitude more
/// slack than the error. Promising a direction here would buy no safety while
/// committing the word to a property that does not hold uniformly: the
/// subtraction truncates away from zero for same-signed values and toward it
/// for values that straddle zero.
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
                // two values are numerically equal, matching `referenceFn`.
                //
                // This is consistency, not a correctness requirement. An
                // earlier revision anchored the limit on the lowest value, so
                // its packing fed the rounding and the two sides had to agree
                // on the tie break. Under the current formula they do not:
                // `mul` is invariant under factor-of-ten repackings and `sub`
                // maximizes both operands first, so the packing is normalised
                // away. Relaxing this to `lte` changes no answer the tests can
                // produce.
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
        return LibDecimalFloat.agree(absolute, proportional, lowest, highest);
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
