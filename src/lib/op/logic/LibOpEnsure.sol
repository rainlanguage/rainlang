// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {LibIntOrAString, IntOrAString} from "rain.intorastring/lib/LibIntOrAString.sol";
import {Float, LibDecimalFloat} from "rain.math.float/lib/LibDecimalFloat.sol";

/// @title LibOpEnsure
/// @notice Opcode to revert if the condition is zero.
library LibOpEnsure {
    using LibDecimalFloat for Float;
    using LibIntOrAString for IntOrAString;

    /// @notice `ensure` integrity check. Requires exactly 2 inputs and
    /// produces 0 outputs.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        return (2, 0);
    }

    /// @notice `ensure`
    /// If the condition is zero, the expression will revert with the given
    /// string.
    /// All conditions are eagerly evaluated and there are no outputs.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2, Pointer stackTop) internal pure returns (Pointer) {
        Float condition;
        IntOrAString reason;
        assembly ("memory-safe") {
            condition := mload(stackTop)
            reason := mload(add(stackTop, 0x20))
            stackTop := add(stackTop, 0x40)
        }

        if (condition.isZero()) {
            revert(reason.toStringV3());
        }
        return stackTop;
    }

    /// @notice Gas intensive reference implementation of `ensure` for testing.
    /// @param inputs The input values from the stack.
    /// @return outputs The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory outputs)
    {
        require(
            !Float.wrap(StackItem.unwrap(inputs[0])).isZero(),
            IntOrAString.wrap(uint256(StackItem.unwrap(inputs[1]))).toStringV3()
        );
        outputs = new StackItem[](0);
    }
}
