// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {LibOpBitwiseEncode} from "./LibOpBitwiseEncode.sol";

/// @title LibOpBitwiseDecode
/// @notice Opcode for decoding binary data from a 256 bit value that was encoded
/// with LibOpBitwiseEncode.
library LibOpBitwiseDecode {
    /// @notice Decode takes a single value and returns the decoded value.
    /// @param state The current integrity check state.
    /// @param operand The operand for this opcode.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory state, OperandV2 operand) internal pure returns (uint256, uint256) {
        // Use exact same integrity check as encode other than the return values.
        // All we're interested in is the errors that might be thrown.
        //slither-disable-next-line unused-return
        LibOpBitwiseEncode.integrity(state, operand);

        return (1, 1);
    }

    /// @notice `decode-bits` opcode. Decodes a value from the bit position and length specified by the operand.
    /// @param operand The operand encoding the start bit and length.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2 operand, Pointer stackTop) internal pure returns (Pointer) {
        unchecked {
            uint256 value;
            assembly ("memory-safe") {
                value := mload(stackTop)
            }

            // We decode as a start and length of bits. This avoids mistakes such as
            // inclusive/exclusive ranges, and makes it easier to reason about the
            // encoding.
            uint256 startBit = uint256(OperandV2.unwrap(operand) & bytes32(uint256(0xFF)));
            uint256 length = uint256((OperandV2.unwrap(operand) >> 8) & bytes32(uint256(0xFF)));

            // Build a bitmask of desired length. Max length is uint8 max which
            // is 255. A 256 length doesn't really make sense as that isn't an
            // encoding anyway, it's just the value verbatim.
            //slither-disable-next-line incorrect-shift
            //forge-lint: disable-next-line(incorrect-shift)
            uint256 mask = (1 << length) - 1;
            value = (value >> startBit) & mask;

            assembly ("memory-safe") {
                mstore(stackTop, value)
            }
            return stackTop;
        }
    }

    /// @notice Reference implementation of `decode-bits` for testing.
    /// @param operand The operand encoding the start bit and length.
    /// @param inputs The input values from the stack.
    /// @return outputs The decoded output values.
    function referenceFn(InterpreterState memory, OperandV2 operand, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory)
    {
        // We decode as a start and length of bits. This avoids mistakes such as
        // inclusive/exclusive ranges, and makes it easier to reason about the
        // encoding.
        uint256 startBit = uint256(OperandV2.unwrap(operand) & bytes32(uint256(0xFF)));
        uint256 length = uint256((OperandV2.unwrap(operand) >> 8) & bytes32(uint256(0xFF)));

        // Build a bitmask of desired length. Max length is uint8 max which
        // is 255. A 256 length doesn't really make sense as that isn't an
        // encoding anyway, it's just the value verbatim.
        uint256 mask = (2 ** length) - 1;
        inputs[0] = StackItem.wrap(bytes32((uint256(StackItem.unwrap(inputs[0])) >> startBit) & mask));
        return inputs;
    }
}
