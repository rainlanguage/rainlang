// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ParseState} from "./LibParseState.sol";

/// @dev Magic number ORed into the high bits of every parse error offset so
/// that callers can distinguish Rain parse errors from other revert data.
/// Shifted left by 0x10 (16 bits) to leave room for the offset in the low
/// bytes.
bytes32 constant MAGIC_NUMBER_RAIN_PARSE_ERROR_V1 = keccak256("rain.interpreter.error.parse.0") << 0x10;

/// @title LibParseError
/// @notice Utilities for computing error offsets during parsing.
library LibParseError {
    /// @notice Calculates the byte offset of a cursor position relative to the start
    /// of the parse data, for use in error reporting. The offset is ORed with
    /// `MAGIC_NUMBER_RAIN_PARSE_ERROR_V1` so that callers can identify Rain
    /// parse errors by checking the high bits.
    /// @param state The parser state containing the source data reference.
    /// @param cursor The cursor position to calculate the offset for.
    /// @return offset The byte offset from the start of the parse data, ORed
    /// with the magic number.
    function parseErrorOffset(ParseState memory state, uint256 cursor) internal pure returns (uint256 offset) {
        bytes memory data = state.data;
        assembly ("memory-safe") {
            offset := sub(cursor, add(data, 0x20))
        }
        offset = tagErrorOffset(offset);
    }

    /// @notice Returns `true` if the given error offset was produced by
    /// `parseErrorOffset`, i.e. it contains the magic number in its high bits.
    /// @param errorOffset The error offset to check.
    /// @return True if the magic number is present.
    function isRainParseError(uint256 errorOffset) internal pure returns (bool) {
        return (errorOffset & uint256(MAGIC_NUMBER_RAIN_PARSE_ERROR_V1)) == uint256(MAGIC_NUMBER_RAIN_PARSE_ERROR_V1);
    }

    /// @notice Extracts the raw byte offset from a magic-number-tagged error
    /// offset by masking out the magic number bits.
    /// @param errorOffset The tagged error offset.
    /// @return The raw byte offset within the parse data.
    function parseOffset(uint256 errorOffset) internal pure returns (uint256) {
        return errorOffset & ~uint256(MAGIC_NUMBER_RAIN_PARSE_ERROR_V1);
    }

    /// @notice Tags a plain byte offset with the magic number. This is the
    /// inverse of `parseOffset` and produces the same result as
    /// `parseErrorOffset` without requiring a `ParseState`.
    /// @param offset The plain byte offset to tag.
    /// @return The offset ORed with `MAGIC_NUMBER_RAIN_PARSE_ERROR_V1`.
    function tagErrorOffset(uint256 offset) internal pure returns (uint256) {
        return uint256(MAGIC_NUMBER_RAIN_PARSE_ERROR_V1) | offset;
    }

    /// @notice Reverts with the given error selector and the cursor's byte offset if
    /// the selector is non-zero. A zero selector indicates no error.
    /// @param state The parser state for error offset calculation.
    /// @param cursor The cursor position for the error offset.
    /// @param errorSelector The 4-byte error selector to revert with, or
    /// zero for no error.
    function handleErrorSelector(ParseState memory state, uint256 cursor, bytes4 errorSelector) internal pure {
        if (errorSelector != 0) {
            uint256 errorOffset = parseErrorOffset(state, cursor);
            assembly ("memory-safe") {
                mstore(0, errorSelector)
                mstore(4, errorOffset)
                revert(0, 0x24)
            }
        }
    }
}
