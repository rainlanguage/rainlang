// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {Float, LibDecimalFloat} from "rain.math.float/lib/LibDecimalFloat.sol";

/// @title LibOpIf
/// @notice Opcode to choose between two values based on a condition. If is
/// eager, meaning both values are evaluated before the condition is checked.
library LibOpIf {
    using LibDecimalFloat for Float;

    /// @notice `if` integrity check. Requires exactly 3 inputs and produces 1 output.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        return (3, 1);
    }

    /// @notice IF
    /// IF is a conditional. If the first item on the stack is nonzero, the second
    /// item is returned, else the third item is returned.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2, Pointer stackTop) internal pure returns (Pointer) {
        Float condition;
        assembly ("memory-safe") {
            condition := mload(stackTop)
            stackTop := add(stackTop, 0x40)
        }

        bool isZero = condition.isZero();

        assembly ("memory-safe") {
            mstore(stackTop, mload(sub(stackTop, mul(0x20, iszero(isZero)))))
        }
        return stackTop;
    }

    /// @notice Gas intensive reference implementation of IF for testing.
    /// @param inputs The input values from the stack.
    /// @return outputs The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory outputs)
    {
        outputs = new StackItem[](1);
        outputs[0] = Float.wrap(StackItem.unwrap(inputs[0])).isZero() ? inputs[2] : inputs[1];
    }
}
