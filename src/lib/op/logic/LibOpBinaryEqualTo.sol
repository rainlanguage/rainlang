// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";

/// @title LibOpBinaryEqualTo
/// @notice Opcode to return 1 if the first item on the stack is equal to
/// the second item on the stack, else 0.
library LibOpBinaryEqualTo {
    /// @notice `binary-equal-to` integrity check. Requires exactly 2 inputs and produces 1 output.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        return (2, 1);
    }

    /// @notice Binary Equality
    /// Binary Equality is 1 if the first item is equal to the second item,
    /// else 0.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2, Pointer stackTop) internal pure returns (Pointer) {
        assembly ("memory-safe") {
            let a := mload(stackTop)
            stackTop := add(stackTop, 0x20)
            mstore(stackTop, eq(a, mload(stackTop)))
        }
        return stackTop;
    }

    /// @notice Gas intensive reference implementation of binary equal for testing.
    /// @param inputs The input values from the stack.
    /// @return outputs The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory outputs)
    {
        outputs = new StackItem[](1);
        outputs[0] =
            StackItem.wrap(bytes32(uint256(StackItem.unwrap(inputs[0]) == StackItem.unwrap(inputs[1]) ? 1 : 0)));
    }
}
