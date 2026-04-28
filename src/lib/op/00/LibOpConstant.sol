// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OutOfBoundsConstantRead} from "../../../error/ErrIntegrity.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";

/// @title LibOpConstant
/// @notice Implementation of copying a constant from the constants array to the stack.
/// Integrated deeply into LibParse, which requires this opcode or a variant
/// to be present at a known opcode index.
library LibOpConstant {
    /// @notice `constant` integrity check. Validates the constant index is within bounds.
    /// @param state The current integrity check state containing the constants.
    /// @param operand Encodes the constant index in the low 16 bits.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory state, OperandV2 operand) internal pure returns (uint256, uint256) {
        // Operand is the index so ensure it doesn't exceed the constants length.
        uint256 constantIndex = uint256(OperandV2.unwrap(operand) & bytes32(uint256(0xFFFF)));
        if (constantIndex >= state.constants.length) {
            revert OutOfBoundsConstantRead(state.opIndex, state.constants.length, constantIndex);
        }
        // As inputs MUST always be 0, we don't have to check the high byte of
        // the operand here, the integrity check will do that for us.
        return (0, 1);
    }

    /// @notice `constant` opcode. Copies a constant from the constants array to the stack.
    /// @param state The interpreter state containing the constants array.
    /// @param operand Encodes the constant index in the low 16 bits.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory state, OperandV2 operand, Pointer stackTop) internal pure returns (Pointer) {
        bytes32[] memory constants = state.constants;
        // Skip index OOB check and rely on integrity check for that.
        assembly ("memory-safe") {
            let value := mload(add(constants, mul(add(and(operand, 0xFFFF), 1), 0x20)))
            stackTop := sub(stackTop, 0x20)
            mstore(stackTop, value)
        }
        return stackTop;
    }

    /// @notice Reference implementation of `constant` for testing.
    /// @param state The interpreter state containing the constants array.
    /// @param operand Encodes the constant index in the low 16 bits.
    /// @return outputs The output values to push onto the stack.
    function referenceFn(InterpreterState memory state, OperandV2 operand, StackItem[] memory)
        internal
        pure
        returns (StackItem[] memory outputs)
    {
        uint256 index = uint256(OperandV2.unwrap(operand) & bytes32(uint256(0xFFFF)));
        outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(state.constants[index]);
    }
}
