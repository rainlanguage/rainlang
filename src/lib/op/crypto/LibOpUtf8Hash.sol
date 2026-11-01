// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Pointer} from "rain-solmem-0.1.28/src/lib/LibPointer.sol";
import {
    IntOrAString,
    LibIntOrAString,
    LENGTH_MASK_V3,
    TRUTHY_BITS_V3
} from "rain-intorastring-0.1.4/src/lib/LibIntOrAString.sol";
import {OperandV2, StackItem} from "../../../interface/IInterpreterV4.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {NotAString} from "../../../error/ErrRainType.sol";

/// @title LibOpUtf8Hash
/// @notice `utf8-hash`: keccak256 of the UTF-8 bytes of its IntOrAString string
/// inputs, concatenated in order.
library LibOpUtf8Hash {
    using LibIntOrAString for IntOrAString;

    /// @notice Whether `value` is an IntOrAString built by `fromStringV3`: the
    /// truthy bits set and nothing above the string's bytes.
    /// @param value The value to check.
    /// @return Whether it is an IntOrAString string.
    function isIntOrAStringV3(bytes32 value) internal pure returns (bool) {
        uint256 raw = uint256(value);
        uint256 length = raw & LENGTH_MASK_V3;
        return (raw & TRUTHY_BITS_V3) == TRUTHY_BITS_V3 && (raw >> ((length + 1) * 8)) == 0;
    }

    /// @notice `utf8-hash` integrity check. Requires at least 1 input and
    /// produces 1 output.
    /// @param operand The operand encoding the number of inputs.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2 operand) internal pure returns (uint256, uint256) {
        uint256 inputs = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;
        inputs = inputs > 0 ? inputs : 1;
        return (inputs, 1);
    }

    /// @notice `utf8-hash` opcode. Computes keccak256 over the concatenated
    /// string bytes of the operand-specified number of stack items.
    /// @param operand The operand encoding the number of inputs.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2 operand, Pointer stackTop) internal pure returns (Pointer) {
        uint256 inputs = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;
        bytes memory joined;
        for (uint256 i = 0; i < inputs; i++) {
            bytes32 value;
            assembly ("memory-safe") {
                value := mload(add(stackTop, mul(i, 0x20)))
            }
            if (!isIntOrAStringV3(value)) {
                revert NotAString(i, value);
            }
            joined = bytes.concat(joined, bytes(IntOrAString.wrap(uint256(value)).toStringV3()));
        }
        bytes32 hash = keccak256(joined);
        assembly ("memory-safe") {
            stackTop := sub(add(stackTop, mul(inputs, 0x20)), 0x20)
            mstore(stackTop, hash)
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
            bytes32 value = StackItem.unwrap(inputs[i]);
            if (!isIntOrAStringV3(value)) {
                revert NotAString(i, value);
            }
            joined = string.concat(joined, IntOrAString.wrap(uint256(value)).toStringV3());
        }
        StackItem[] memory outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(keccak256(bytes(joined)));
        return outputs;
    }
}
