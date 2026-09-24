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

/// @title LibOpAgreeAbsolute
/// @notice Opcode to return 1 if the highest and lowest of the values are no
/// more than an absolute tolerance apart, else 0.
///
/// The first input is the tolerance and every subsequent input is a value. The
/// check is `highest - lowest <= tolerance`. The tolerance is an absolute
/// quantity in whatever units the values are in, e.g. a number of seconds for
/// timestamps, so passing `now()` alongside signed timestamps bounds both the
/// spread between the signatures and their distance from the chain clock in
/// one call.
///
/// `agree` is the proportional variant of the same check.
///
/// ROUNDING. The spread is compared against the tolerance at full internal
/// precision, i.e. it is never packed back into a `Float`, so the only place a
/// value can be lost is the coefficient alignment inside the subtraction. That
/// alignment truncates the operand with the smaller exponent toward zero. For
/// values that share a sign - the domain this word exists for, prices and
/// timestamps - the operands of `highest + (-lowest)` have opposite signs, so
/// shrinking one of them can only make the spread larger, which only ever
/// rounds toward rejecting. Where the values straddle zero the two operands
/// share a sign and the truncation goes the other way, by at most one unit in
/// the last of ~76 significant digits.
library LibOpAgreeAbsolute {
    using LibDecimalFloat for Float;

    /// @notice `agree-absolute` integrity check. Requires at least 3 inputs
    /// (a tolerance and two values) and produces 1 output. A single value
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

    /// @notice AGREE-ABSOLUTE
    /// 1 if `highest - lowest <= tolerance`, else 0.
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
                // the spread, so the tie break has to be the same in both.
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
                (int256 highestCoefficient, int256 highestExponent) = highest.unpack();
                (int256 lowestCoefficient, int256 lowestExponent) = lowest.unpack();
                (int256 spreadCoefficient, int256 spreadExponent) = LibDecimalFloatImplementation.sub(
                    highestCoefficient, highestExponent, lowestCoefficient, lowestExponent
                );
                (int256 toleranceCoefficient, int256 toleranceExponent) = tolerance.unpack();
                (int256 rescaledSpread, int256 rescaledTolerance) = LibDecimalFloatImplementation.compareRescale(
                    spreadCoefficient, spreadExponent, toleranceCoefficient, toleranceExponent
                );
                agreed = rescaledSpread <= rescaledTolerance;
            }

            stackTop = Pointer.wrap(Pointer.unwrap(end) - 0x20);
            assembly ("memory-safe") {
                mstore(stackTop, agreed)
            }
        }
        return stackTop;
    }

    /// @notice Gas intensive reference implementation of AGREE-ABSOLUTE for
    /// testing.
    /// @param inputs The input values from the stack.
    /// @return outputs The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory outputs)
    {
        Float tolerance = Float.wrap(StackItem.unwrap(inputs[0]));
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

        (int256 highestCoefficient, int256 highestExponent) = highest.unpack();
        (int256 lowestCoefficient, int256 lowestExponent) = lowest.unpack();
        (int256 spreadCoefficient, int256 spreadExponent) =
            LibDecimalFloatImplementation.sub(highestCoefficient, highestExponent, lowestCoefficient, lowestExponent);

        (int256 toleranceCoefficient, int256 toleranceExponent) = tolerance.unpack();
        (int256 rescaledSpread, int256 rescaledTolerance) = LibDecimalFloatImplementation.compareRescale(
            spreadCoefficient, spreadExponent, toleranceCoefficient, toleranceExponent
        );

        outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(bytes32(uint256(rescaledSpread <= rescaledTolerance ? 1 : 0)));
    }
}
