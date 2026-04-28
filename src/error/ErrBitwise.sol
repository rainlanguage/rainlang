// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @dev Workaround for https://github.com/foundry-rs/foundry/issues/6572
contract ErrBitwise {}

/// @notice Thrown during integrity check when a bitwise shift operation is attempted
/// with a shift amount greater than 255 or 0. As the shift amount is taken from
/// the operand, this is a compile time error so there's no need to support
/// behaviour that would always evaluate to 0 or be a noop.
/// @param shiftAmount The unsupported shift amount from the operand.
error UnsupportedBitwiseShiftAmount(uint256 shiftAmount);

/// @notice Thrown during integrity check when bitwise (en|de)coding would be truncated
/// due to the end bit position being beyond 256.
/// @param startBit The start of the OOB encoding.
/// @param length The length of the OOB encoding.
error TruncatedBitwiseEncoding(uint256 startBit, uint256 length);

/// @notice Thrown during integrity check when the length of a bitwise
/// (en|de)coding would be 0.
error ZeroLengthBitwiseEncoding();
