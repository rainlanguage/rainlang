// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";

/// @title LibOpGm
/// @notice Opcode for the signed geometric mean of two decimal floating point
/// numbers. Computes `sign * sqrt(|a| * |b|)`, where the sign is negative when
/// an odd number of inputs are negative.
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
    /// Computes `sign * sqrt(|a| * |b|)`. The result is negative when exactly
    /// one input is negative, positive otherwise.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2, Pointer stackTop) internal view returns (Pointer) {
        Float a;
        Float b;
        assembly ("memory-safe") {
            a := mload(stackTop)
            stackTop := add(stackTop, 0x20)
            b := mload(stackTop)
        }
        bool aNeg = a.lt(LibDecimalFloat.FLOAT_ZERO);
        bool bNeg = b.lt(LibDecimalFloat.FLOAT_ZERO);
        Float result = a.abs().mul(b.abs()).pow(LibDecimalFloat.FLOAT_HALF, LibDecimalFloat.LOG_TABLES_ADDRESS);
        if (aNeg != bNeg) {
            result = result.minus();
        }

        assembly ("memory-safe") {
            mstore(stackTop, result)
        }
        return stackTop;
    }

    /// @notice Gas intensive reference implementation of gm for testing.
    /// @param inputs The input values from the stack.
    /// @return The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        view
        returns (StackItem[] memory)
    {
        // The geometric mean is sign * sqrt(|a| * |b|), where sign is
        // negative if an odd number of inputs are negative.
        Float a = Float.wrap(StackItem.unwrap(inputs[0]));
        Float b = Float.wrap(StackItem.unwrap(inputs[1]));
        bool aNeg = a.lt(LibDecimalFloat.FLOAT_ZERO);
        bool bNeg = b.lt(LibDecimalFloat.FLOAT_ZERO);
        Float result = a.abs().mul(b.abs()).pow(LibDecimalFloat.FLOAT_HALF, LibDecimalFloat.LOG_TABLES_ADDRESS);
        if (aNeg != bNeg) {
            result = result.minus();
        }
        StackItem[] memory outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(Float.unwrap(result));
        return outputs;
    }
}
