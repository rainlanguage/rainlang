// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @dev Workaround for https://github.com/foundry-rs/foundry/issues/6572
contract ErrIntegrity {}

/// @notice The stack underflowed during integrity check.
/// @param opIndex The index of the op in the source.
/// @param stackIndex The current stack index at the point of underflow.
/// @param calculatedInputs The number of inputs that caused the underflow.
error StackUnderflow(uint256 opIndex, uint256 stackIndex, uint256 calculatedInputs);

/// @notice The stack underflowed the highwater during integrity check.
/// @param opIndex The index of the op in the source.
/// @param stackIndex The current stack index at the point of underflow.
/// @param stackHighwater The highwater mark that was underflowed.
error StackUnderflowHighwater(uint256 opIndex, uint256 stackIndex, uint256 stackHighwater);

/// @notice The bytecode stack allocation does not match the allocation calculated by
/// the integrity check.
/// @param stackMaxIndex The maximum stack index calculated by integrity.
/// @param bytecodeAllocation The stack allocation specified in the bytecode.
error StackAllocationMismatch(uint256 stackMaxIndex, uint256 bytecodeAllocation);

/// @notice The final stack index does not match the bytecode outputs.
/// @param stackIndex The final stack index after integrity check.
/// @param bytecodeOutputs The number of outputs specified in the bytecode.
error StackOutputsMismatch(uint256 stackIndex, uint256 bytecodeOutputs);

/// @notice Thrown when a constant read index is outside the constants array.
/// @param opIndex The index of the op in the source.
/// @param constantsLength The length of the constants array.
/// @param constantRead The out-of-bounds constant index that was attempted.
error OutOfBoundsConstantRead(uint256 opIndex, uint256 constantsLength, uint256 constantRead);

/// @notice Thrown when a stack read index is outside the current stack top.
/// @param opIndex The index of the op in the source.
/// @param stackTopIndex The current stack top index.
/// @param stackRead The out-of-bounds stack index that was attempted.
error OutOfBoundsStackRead(uint256 opIndex, uint256 stackTopIndex, uint256 stackRead);

/// @notice Thrown when the outputs requested by the operand exceed the outputs
/// available from the source.
/// @param sourceOutputs The number of outputs available from the source.
/// @param outputs The number of outputs requested by the operand.
error CallOutputsExceedSource(uint256 sourceOutputs, uint256 outputs);

/// @notice Thrown when the inputs encoded in the operand do not match the
/// inputs expected by the target source.
/// @param operandInputs The number of inputs encoded in the operand.
/// @param sourceInputs The number of inputs expected by the source.
error CallInputsMismatchSource(uint256 operandInputs, uint256 sourceInputs);

/// @notice Thrown when a bytecode opcode index is outside the function pointer table.
/// @param opIndex The index of the op in the source.
/// @param opcodeIndex The out-of-bounds opcode index from the bytecode.
/// @param fsCount The number of function pointers in the table.
error OpcodeOutOfRange(uint256 opIndex, uint256 opcodeIndex, uint256 fsCount);
