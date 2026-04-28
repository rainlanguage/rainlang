// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ZeroLengthBitwiseEncoding, TruncatedBitwiseEncoding} from "../../../error/ErrBitwise.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";

/// @title LibOpBitwiseEncode
/// @notice Opcode for encoding binary data into a 256 bit value.
library LibOpBitwiseEncode {
    /// @notice Encode takes two values and returns one value. The first value is the
    /// source, the second value is the target.
    /// @param operand The operand encoding the start bit and length.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2 operand) internal pure returns (uint256, uint256) {
        uint256 startBit = uint256(OperandV2.unwrap(operand) & bytes32(uint256(0xFF)));
        uint256 length = uint256((OperandV2.unwrap(operand) >> 8) & bytes32(uint256(0xFF)));

        if (length == 0) {
            revert ZeroLengthBitwiseEncoding();
        }
        if (startBit + length > 256) {
            revert TruncatedBitwiseEncoding(startBit, length);
        }
        return (2, 1);
    }

    /// @notice `encode-bits` opcode. Encodes a source value into a target at the bit position and length specified by the operand.
    /// @param operand The operand encoding the start bit and length.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2 operand, Pointer stackTop) internal pure returns (Pointer) {
        unchecked {
            uint256 source;
            uint256 target;
            assembly ("memory-safe") {
                source := mload(stackTop)
                stackTop := add(stackTop, 0x20)
                target := mload(stackTop)
            }

            // We encode as a start and length of bits. This avoids mistakes such as
            // inclusive/exclusive ranges, and makes it easier to reason about the
            // encoding.
            uint256 startBit = uint256(OperandV2.unwrap(operand) & bytes32(uint256(0xFF)));
            uint256 length = uint256((OperandV2.unwrap(operand) >> 8) & bytes32(uint256(0xFF)));

            // Build a bitmask of desired length. Max length is uint8 max which
            // is 255. A 256 length doesn't really make sense as that isn't an
            // encoding anyway, it's just the source verbatim.
            //slither-disable-next-line incorrect-shift
            //forge-lint: disable-next-line(incorrect-shift)
            uint256 mask = ((1 << length) - 1);

            // Punch a mask sized hole in target.
            target &= ~(mask << startBit);

            // Fill the hole with masked bytes from source.
            target |= (source & mask) << startBit;

            assembly ("memory-safe") {
                mstore(stackTop, target)
            }
            return stackTop;
        }
    }

    /// @notice Reference implementation of `encode-bits` for testing.
    /// @param operand The operand encoding the start bit and length.
    /// @param inputs The input values from the stack.
    /// @return outputs The encoded output values.
    function referenceFn(InterpreterState memory, OperandV2 operand, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory outputs)
    {
        uint256 source = uint256(StackItem.unwrap(inputs[0]));
        uint256 target = uint256(StackItem.unwrap(inputs[1]));

        // We encode as a start and length of bits. This avoids mistakes such as
        // inclusive/exclusive ranges, and makes it easier to reason about the
        // encoding.
        uint256 startBit = uint256(OperandV2.unwrap(operand) & bytes32(uint256(0xFF)));
        uint256 length = uint256((OperandV2.unwrap(operand) >> 8) & bytes32(uint256(0xFF)));

        // Build a bitmask of desired length. Max length is uint8 max which
        // is 255. A 256 length doesn't really make sense as that isn't an
        // encoding anyway, it's just the source verbatim.
        uint256 mask = (2 ** length - 1);

        // Punch a mask sized hole in target.
        target &= ~(mask << startBit);

        // Fill the hole with masked bytes from source.
        target |= (source & mask) << startBit;

        outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(bytes32(target));
    }
}
