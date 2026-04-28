// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";

/// @title LibOpHeadroom
/// @notice Opcode for the headroom (distance to ceil) of a decimal floating
/// point number.
library LibOpHeadroom {
    using LibDecimalFloat for Float;

    /// @notice `headroom` integrity check. Requires exactly 1 input and produces 1 output.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        // There must be one input and one output.
        return (1, 1);
    }

    /// @notice Decimal floating point headroom (distance to ceil) of a number.
    /// Returns `ceil(x) - x`, except when `x` is already an integer
    /// (headroom would be zero), in which case it returns 1.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The updated stack top with the headroom written.
    function run(InterpreterState memory, OperandV2, Pointer stackTop) internal pure returns (Pointer) {
        Float a;
        assembly ("memory-safe") {
            a := mload(stackTop)
        }
        a = a.ceil().sub(a);
        if (a.isZero()) {
            a = LibDecimalFloat.FLOAT_ONE;
        }

        assembly ("memory-safe") {
            mstore(stackTop, a)
        }
        return stackTop;
    }

    /// @notice Gas intensive reference implementation of headroom for testing.
    /// @param inputs The input values from the stack.
    /// @return The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory)
    {
        // The headroom is 1 - frac(x).
        Float a = Float.wrap(StackItem.unwrap(inputs[0]));
        a = a.ceil().sub(a);
        if (a.isZero()) {
            a = LibDecimalFloat.FLOAT_ONE;
        }

        StackItem[] memory outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(Float.unwrap(a));
        return outputs;
    }
}
