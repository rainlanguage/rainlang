// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Pointer} from "rain-solmem-0.1.28/src/lib/LibPointer.sol";
import {IntOrAString, LibIntOrAString, LENGTH_MASK_V3} from "rain-intorastring-0.1.4/src/lib/LibIntOrAString.sol";
import {OperandV2, StackItem} from "../../../interface/IInterpreterV4.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";

/// @title LibOpStringCount
/// @notice `string-count`: the byte length of an IntOrAString string, as a Float.
library LibOpStringCount {
    using LibIntOrAString for IntOrAString;

    /// @notice `string-count` integrity check. Requires exactly 1 input and
    /// produces 1 output.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        return (1, 1);
    }

    /// @notice `string-count` opcode. Replaces the string on the stack with its
    /// byte length.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2, Pointer stackTop) internal pure returns (Pointer) {
        uint256 lengthMask = LENGTH_MASK_V3;
        assembly ("memory-safe") {
            mstore(stackTop, and(mload(stackTop), lengthMask))
        }
        return stackTop;
    }

    /// @notice Reference implementation of `string-count` for testing.
    /// @param inputs The input values from the stack.
    /// @return The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory)
    {
        StackItem[] memory outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(
            bytes32(bytes(IntOrAString.wrap(uint256(StackItem.unwrap(inputs[0]))).toStringV3()).length)
        );
        return outputs;
    }
}
