// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ParseState} from "../LibParseState.sol";
import {IntOrAString, LibIntOrAString} from "rain.intorastring/lib/LibIntOrAString.sol";
import {UnclosedStringLiteral, StringTooLong} from "../../../error/ErrParse.sol";
import {CMASK_STRING_LITERAL_END, CMASK_STRING_LITERAL_TAIL} from "rain.string/lib/parse/LibParseCMask.sol";
import {LibParseError} from "../LibParseError.sol";

/// @title LibParseLiteralString
/// @notice A library for parsing string literals.
library LibParseLiteralString {
    using LibParseError for ParseState;
    using LibParseLiteralString for ParseState;

    /// @notice Find the bounds for some string literal at the cursor. The caller is
    /// responsible for checking that the cursor is at the start of a string
    /// literal. Bounds are as per `boundLiteral`.
    /// @param state The current parse state.
    /// @param cursor The cursor position at the start of the string literal.
    /// @param end The end of the source string.
    /// @return The start of the string content (past opening quote).
    /// @return The end of the string content (before closing quote).
    /// @return The new cursor position after the string literal.
    function boundString(ParseState memory state, uint256 cursor, uint256 end)
        internal
        pure
        returns (uint256, uint256, uint256)
    {
        unchecked {
            uint256 innerStart = cursor + 1;
            uint256 innerEnd;
            uint256 outerEnd;
            {
                uint256 stringCharMask = CMASK_STRING_LITERAL_TAIL;
                uint256 stringData;
                uint256 i = 0;
                assembly ("memory-safe") {
                    let distanceFromEnd := sub(end, innerStart)
                    let max := 0x20
                    if lt(distanceFromEnd, 0x20) { max := distanceFromEnd }

                    // Only up to 31 bytes of string data can be stored in a
                    // single word, so strings can't be longer than 31 bytes.
                    // The 32nd byte is the length of the string.
                    stringData := mload(innerStart)
                    //slither-disable-next-line incorrect-shift
                    for {} and(lt(i, max), iszero(iszero(and(shl(byte(i, stringData), 1), stringCharMask)))) {} {
                        i := add(i, 1)
                    }
                }
                if (i == 0x20) {
                    revert StringTooLong(state.parseErrorOffset(cursor));
                }
                innerEnd = innerStart + i;
                uint256 finalChar;
                assembly ("memory-safe") {
                    finalChar := byte(0, mload(innerEnd))
                }

                // End can't equal inner end, because then we would move past the
                // end of the data considering the final " character.
                //slither-disable-next-line incorrect-shift
                //forge-lint: disable-next-line(incorrect-shift)
                if (1 << finalChar & CMASK_STRING_LITERAL_END == 0 || end == innerEnd) {
                    revert UnclosedStringLiteral(state.parseErrorOffset(innerEnd));
                }
                // Outer end is after the final `"`.
                outerEnd = innerEnd + 1;
            }

            return (innerStart, innerEnd, outerEnd);
        }
    }

    /// @notice Algorithm for parsing string literals:
    /// - Get the inner length of the string
    /// - Mutate memory in place to add a length prefix, record the original data
    /// - Use this solidity string to build an `IntOrAString`
    /// - Restore the original data that the length prefix overwrote
    /// - Return the `IntOrAString`
    /// @param state The current parse state.
    /// @param cursor The cursor position at the start of the string literal.
    /// @param end The end of the source string.
    /// @return The updated cursor position after parsing.
    /// @return The parsed string as an IntOrAString in bytes32 form.
    function parseString(ParseState memory state, uint256 cursor, uint256 end)
        internal
        pure
        returns (uint256, bytes32)
    {
        uint256 stringStart;
        uint256 stringEnd;
        (stringStart, stringEnd, cursor) = state.boundString(cursor, end);
        IntOrAString intOrAString;

        uint256 memSnapshot;
        string memory str;
        assembly ("memory-safe") {
            let length := sub(stringEnd, stringStart)
            str := sub(stringStart, 0x20)
            memSnapshot := mload(str)
            mstore(str, length)
        }
        intOrAString = LibIntOrAString.fromStringV3(str);
        assembly ("memory-safe") {
            mstore(str, memSnapshot)
        }
        return (cursor, bytes32(IntOrAString.unwrap(intOrAString)));
    }
}
