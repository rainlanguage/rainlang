// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OperandV2, StackItem} from "../../../interface/IInterpreterV4.sol";
import {Pointer} from "rain-solmem-0.1.28/src/lib/LibPointer.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {LibDecimalFloat, Float} from "rain-math-float-0.3.11/src/lib/LibDecimalFloat.sol";
import {
    LibDecimalFloatImplementation
} from "rain-math-float-0.3.11/src/lib/implementation/LibDecimalFloatImplementation.sol";
import {Math} from "@openzeppelin-contracts-5.7.0/utils/math/Math.sol";

/// @title LibOpGm
/// @notice Opcode for the signed geometric mean of two decimal floating point
/// numbers, `LibDecimalFloat.gm`: `sign * sqrt(|a| * |b|)`, negative when
/// exactly one input is negative. Never reverts.
library LibOpGm {
    using LibDecimalFloat for Float;

    /// @notice `gm` integrity check. Requires exactly 2 inputs and produces 1 output.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        // There must be two inputs and one output.
        return (2, 1);
    }

    /// @notice Signed geometric mean of two decimal floating point numbers.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2, Pointer stackTop) internal pure returns (Pointer) {
        Float a;
        Float b;
        assembly ("memory-safe") {
            a := mload(stackTop)
            stackTop := add(stackTop, 0x20)
            b := mload(stackTop)
        }
        Float result = a.gm(b);

        assembly ("memory-safe") {
            mstore(stackTop, result)
        }
        return stackTop;
    }

    /// @notice Gas intensive reference implementation of gm for testing. The
    /// root of the exact product floored to under 1e76, clamped between the
    /// magnitudes, ordered by value then by smaller coefficient.
    /// @param inputs The input values from the stack.
    /// @return The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory)
    {
        Float a = Float.wrap(StackItem.unwrap(inputs[0]));
        Float b = Float.wrap(StackItem.unwrap(inputs[1]));
        StackItem[] memory outputs = new StackItem[](1);
        if (a.isZero() || b.isZero()) {
            outputs[0] = StackItem.wrap(Float.unwrap(LibDecimalFloat.FLOAT_ZERO));
            return outputs;
        }
        (int256 coefficientA, int256 exponentA) = a.unpack();
        (int256 coefficientB, int256 exponentB) = b.unpack();
        bool negative = (coefficientA < 0) != (coefficientB < 0);
        uint256 magnitudeA = uint256(coefficientA < 0 ? -coefficientA : coefficientA);
        uint256 magnitudeB = uint256(coefficientB < 0 ? -coefficientB : coefficientB);

        uint256 digits = Math.log10(magnitudeA) + Math.log10(magnitudeB) + 2;
        uint256 shift = digits > 77 ? digits - 77 : 0;
        uint256 product = Math.mulDiv(magnitudeA, magnitudeB, 10 ** shift);
        while (product >= 1e76) {
            shift++;
            product = Math.mulDiv(magnitudeA, magnitudeB, 10 ** shift);
        }
        (int256 coefficient, int256 exponent) =
            LibDecimalFloatImplementation.sqrt(int256(product), exponentA + exponentB + int256(shift));

        int256 lowCoefficient = int256(magnitudeA);
        int256 lowExponent = exponentA;
        int256 highCoefficient = int256(magnitudeB);
        int256 highExponent = exponentB;
        bool aIsLow = LibDecimalFloatImplementation.lt(lowCoefficient, lowExponent, highCoefficient, highExponent)
            || (
                LibDecimalFloatImplementation.eq(lowCoefficient, lowExponent, highCoefficient, highExponent)
                    && magnitudeA <= magnitudeB
            );
        if (!aIsLow) {
            (lowCoefficient, lowExponent, highCoefficient, highExponent) =
                (highCoefficient, highExponent, lowCoefficient, lowExponent);
        }
        if (!LibDecimalFloatImplementation.lt(lowCoefficient, lowExponent, coefficient, exponent)) {
            (coefficient, exponent) = (lowCoefficient, lowExponent);
        } else if (!LibDecimalFloatImplementation.lt(coefficient, exponent, highCoefficient, highExponent)) {
            (coefficient, exponent) = (highCoefficient, highExponent);
        }
        if (negative) {
            coefficient = -coefficient;
        }
        (Float result,) = LibDecimalFloat.packLossy(coefficient, exponent);
        outputs[0] = StackItem.wrap(Float.unwrap(result));
        return outputs;
    }
}
