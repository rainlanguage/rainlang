// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {LibCtPop} from "rain.math.binary/lib/LibCtPop.sol";

/// @title LibOpBitwiseCountOnes
/// @notice An opcode that counts the number of bits set in a word. Also known
/// as "population count", "Hamming weight", or "ctpop".
/// There is no evm opcode for this, so we have to implement it ourselves.
library LibOpBitwiseCountOnes {
    /// @notice ctpop unconditionally takes one value and returns one value.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        return (1, 1);
    }

    /// @notice Output is the number of bits set to one in the input. Thin wrapper around
    /// `LibCtPop.ctpop`.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2, Pointer stackTop) internal pure returns (Pointer) {
        uint256 value;
        assembly ("memory-safe") {
            value := mload(stackTop)
        }
        unchecked {
            value = LibCtPop.ctpop(value);
        }
        assembly ("memory-safe") {
            mstore(stackTop, value)
        }
        return stackTop;
    }

    /// @notice The reference implementation of ctpop.
    /// @param inputs The input values from the stack.
    /// @return The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory)
    {
        inputs[0] = StackItem.wrap(bytes32(LibCtPop.ctpopSlow(uint256(StackItem.unwrap(inputs[0])))));
        return inputs;
    }
}
