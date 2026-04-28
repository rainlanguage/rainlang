// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @dev Workaround for https://github.com/foundry-rs/foundry/issues/6572
contract ErrSubParse {}

/// @notice Thrown when a subparser is asked to build an extern dispatch when the
/// constants height is outside the range a single byte can represent.
/// @param constantsHeight The constants height that overflowed.
error ExternDispatchConstantsHeightOverflow(uint256 constantsHeight);

/// @notice Thrown when a subparser is asked to build a constant opcode when the
/// constants height overflows the 16-bit operand encoding.
/// @param constantsHeight The constants height that overflowed.
error ConstantOpcodeConstantsHeightOverflow(uint256 constantsHeight);

/// @notice Thrown when a context column or row overflows uint8.
/// @param column The column value that overflowed.
/// @param row The row value that overflowed.
error ContextGridOverflow(uint256 column, uint256 row);

/// @notice Thrown when a sub parser dispatch index is out of bounds for the
/// function pointer table.
/// @param index The out-of-bounds index.
/// @param length The number of function pointers available.
error SubParserIndexOutOfBounds(uint256 index, uint256 length);

/// @notice Thrown when the dispatch region passed to `subParseLiteral` exceeds
/// the 16-bit encoding limit (0xFFFF bytes). The dispatch length is packed into
/// a 2-byte field; values above 0xFFFF would be silently truncated.
/// @param dispatchLength The dispatch length that overflowed.
error SubParseLiteralDispatchLengthOverflow(uint256 dispatchLength);
