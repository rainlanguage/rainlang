// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// Thrown when a bytecode source index is out of bounds.
/// @param sourceIndex The source index that was out of bounds.
/// @param bytecode The bytecode that was inspected.
error SourceIndexOutOfBounds(uint256 sourceIndex, bytes bytecode);

/// Thrown when a bytecode reports itself as 0 sources but has more than 1 byte.
/// @param bytecode The bytecode that was inspected.
error UnexpectedSources(bytes bytecode);

/// Thrown when bytes are discovered between the offsets and the sources.
/// @param bytecode The bytecode that was inspected.
error UnexpectedTrailingOffsetBytes(bytes bytecode);

/// Thrown when the end of a source as self reported by its header doesnt match
/// the start of the next source or the end of the bytecode.
/// @param bytecode The bytecode that was inspected.
error TruncatedSource(bytes bytecode);

/// Thrown when the offset to a source points to a location that cannot fit a
/// header before the start of the next source or the end of the bytecode.
/// @param bytecode The bytecode that was inspected.
error TruncatedHeader(bytes bytecode);

/// Thrown when the bytecode is truncated before the end of the header offsets.
/// @param bytecode The bytecode that was inspected.
error TruncatedHeaderOffsets(bytes bytecode);

/// Thrown when the stack sizings, allocation, inputs and outputs, are not
/// monotonically increasing.
/// @param bytecode The bytecode that was inspected.
/// @param relativeOffset The relative offset of the source that was inspected.
error StackSizingsNotMonotonic(bytes bytecode, uint256 relativeOffset);
