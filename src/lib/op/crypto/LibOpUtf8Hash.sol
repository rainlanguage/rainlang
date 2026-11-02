// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Pointer} from "rain-solmem-0.1.28/src/lib/LibPointer.sol";
import {IntOrAString, LibIntOrAString, LENGTH_MASK_V3} from "rain-intorastring-0.1.4/src/lib/LibIntOrAString.sol";
import {OperandV2, StackItem} from "../../../interface/IInterpreterV4.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";

/// @title LibOpUtf8Hash
/// @notice `utf8-hash`: keccak256 of the UTF-8 bytes of its IntOrAString string
/// inputs, concatenated in order.
library LibOpUtf8Hash {
    using LibIntOrAString for IntOrAString;

    /// @notice `utf8-hash` integrity check. Inputs count is operand-defined,
    /// produces 1 output. 0 inputs hashes empty (0 length) bytes.
    /// @param operand The operand encoding the number of inputs.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2 operand) internal pure returns (uint256, uint256) {
        uint256 inputs = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;
        return (inputs, 1);
    }

    /// @notice `utf8-hash` opcode. Computes keccak256 over the concatenated
    /// string bytes of the operand-specified number of stack items.
    /// @param operand The operand encoding the number of inputs.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2 operand, Pointer stackTop) internal pure returns (Pointer) {
        uint256 inputs = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;
        uint256 lengthMask = LENGTH_MASK_V3;
        assembly ("memory-safe") {
            // Unallocated memory past the free memory pointer is scratch for the joined bytes.
            let start := mload(0x40)
            let cursor := start
            let end := add(stackTop, mul(inputs, 0x20))
            for { let item := stackTop } lt(item, end) { item := add(item, 0x20) } {
                let value := mload(item)
                let length := and(value, lengthMask)
                mstore(cursor, shl(sub(256, mul(8, length)), shr(8, value)))
                cursor := add(cursor, length)
            }
            stackTop := sub(end, 0x20)
            mstore(stackTop, keccak256(start, sub(cursor, start)))
        }
        return stackTop;
    }

    /// @notice Reference implementation of `utf8-hash` for testing.
    /// @param inputs The input values from the stack.
    /// @return The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory)
    {
        string memory joined = "";
        for (uint256 i = 0; i < inputs.length; i++) {
            joined = string.concat(joined, IntOrAString.wrap(uint256(StackItem.unwrap(inputs[i]))).toStringV3());
        }
        StackItem[] memory outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(keccak256(bytes(joined)));
        return outputs;
    }
}
