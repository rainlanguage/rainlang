// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {SourceIndexOutOfBounds} from "../../../../src/lib/bytecode/LibBytecode.sol";
import {Pointer, LibPointer} from "rain-solmem-0.1.28/src/lib/LibPointer.sol";
import {LibBytes} from "rain-solmem-0.1.28/src/lib/LibBytes.sol";

library LibBytecodeSlow {
    using LibBytes for bytes;
    using LibPointer for Pointer;

    function sourceCountSlow(bytes memory bytecode) internal pure returns (uint256) {
        if (bytecode.length == 0) {
            return 0;
        } else {
            return uint8(bytecode[0]);
        }
    }

    function sourceRelativeOffsetSlow(bytes memory bytecode, uint256 sourceIndex) internal pure returns (uint256) {
        uint256 sourceCount = sourceCountSlow(bytecode);
        if (sourceIndex >= sourceCount) {
            revert SourceIndexOutOfBounds(sourceIndex, bytecode);
        } else {
            uint256 offsetPosition = 1 + sourceIndex * 2;
            return uint256(uint8(bytecode[offsetPosition])) << 8 | uint256(uint8(bytecode[offsetPosition + 1]));
        }
    }

    function sourcePointerSlow(bytes memory bytecode, uint256 sourceIndex) internal pure returns (Pointer) {
        return bytecode.dataPointer()
            .unsafeAddBytes(sourceRelativeOffsetSlow(bytecode, sourceIndex) + 1 + sourceCountSlow(bytecode) * 2);
    }

    /// source count is the top byte of the first word of the source header.
    function sourceOpsCountSlow(bytes memory bytecode, uint256 sourceIndex) internal pure returns (uint256) {
        Pointer pointer = sourcePointerSlow(bytecode, sourceIndex);
        bytes32 word = pointer.unsafeReadWord();
        return uint256(word >> 0xF8);
    }

    /// stack allocation is the second byte from the top of the first word of the
    /// source header.
    function sourceStackAllocationSlow(bytes memory bytecode, uint256 sourceIndex) internal pure returns (uint256) {
        Pointer pointer = sourcePointerSlow(bytecode, sourceIndex);
        bytes32 word = pointer.unsafeReadWord();
        return uint256((word >> 0xF0) & bytes32(uint256(0xFF)));
    }

    /// source inputs and outputs are the third and fourth bytes from the top of
    /// the first word of the source header.
    function sourceInputsOutputsLengthSlow(bytes memory bytecode, uint256 sourceIndex)
        internal
        pure
        returns (uint256 inputs, uint256 outputs)
    {
        Pointer pointer = sourcePointerSlow(bytecode, sourceIndex);
        bytes32 word = pointer.unsafeReadWord();
        inputs = uint256((word >> 0xE8) & bytes32(uint256(0xFF)));
        outputs = uint256((word >> 0xE0) & bytes32(uint256(0xFF)));
    }
}
