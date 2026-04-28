// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {LibParseState, ParseState} from "./LibParseState.sol";
import {CMASK_WHITESPACE} from "rain.string/lib/parse/LibParseCMask.sol";
import {NoWhitespaceAfterUsingWordsFrom} from "../../error/ErrParse.sol";
import {LibParseError} from "./LibParseError.sol";
import {LibParseInterstitial} from "./LibParseInterstitial.sol";
import {LibParseLiteral} from "./literal/LibParseLiteral.sol";

/// @dev The raw bytes of the pragma keyword "using-words-from".
bytes constant PRAGMA_KEYWORD_BYTES = bytes("using-words-from");
/// @dev The pragma keyword as a left-aligned bytes32 for single-word comparison.
// Constant is safe to typecast.
//forge-lint: disable-next-line(unsafe-typecast)
bytes32 constant PRAGMA_KEYWORD_BYTES32 = bytes32(PRAGMA_KEYWORD_BYTES);
/// @dev The byte length of the pragma keyword (16 bytes for "using-words-from").
uint256 constant PRAGMA_KEYWORD_BYTES_LENGTH = 16;
/// @dev Bitmask that isolates the first `PRAGMA_KEYWORD_BYTES_LENGTH` bytes of
/// a bytes32 value, used to compare only the keyword portion.
//forge-lint: disable-next-line(incorrect-shift)
bytes32 constant PRAGMA_KEYWORD_MASK = bytes32(~((1 << (32 - PRAGMA_KEYWORD_BYTES_LENGTH) * 8) - 1));

/// @title LibParsePragma
/// @notice Parses the `using-words-from` pragma from Rainlang source text
/// and registers sub-parser contract addresses on the parse state.
library LibParsePragma {
    using LibParseError for ParseState;
    using LibParseInterstitial for ParseState;
    using LibParseLiteral for ParseState;
    using LibParseState for ParseState;

    /// @notice Parses an optional `using-words-from` pragma at the cursor. If the
    /// pragma keyword is present, reads one or more literal sub parser
    /// addresses and pushes them onto the state's sub parser list.
    /// @param state The parser state.
    /// @param cursor The current cursor position.
    /// @param end The end of the data to parse.
    /// @return The updated cursor position after the pragma.
    function parsePragma(ParseState memory state, uint256 cursor, uint256 end) internal view returns (uint256) {
        unchecked {
            // Not-pragma guard.
            {
                // There is a pragma if the cursor is pointing exactly at the bytes of
                // the pragma.
                bytes32 maybePragma;
                assembly ("memory-safe") {
                    maybePragma := mload(cursor)
                }
                // Bail without modifying the cursor if there's no pragma.
                if (maybePragma & PRAGMA_KEYWORD_MASK != PRAGMA_KEYWORD_BYTES32) {
                    return cursor;
                }
            }

            {
                // Move past the pragma keyword.
                cursor += PRAGMA_KEYWORD_BYTES_LENGTH;

                // If the input ends exactly at the keyword there is no
                // whitespace char to read.
                if (cursor >= end) {
                    revert NoWhitespaceAfterUsingWordsFrom(state.parseErrorOffset(cursor));
                }

                // Need at least one whitespace char after the pragma keyword.
                uint256 char;
                assembly ("memory-safe") {
                    //slither-disable-next-line incorrect-shift
                    char := shl(byte(0, mload(cursor)), 1)
                }
                if (char & CMASK_WHITESPACE == 0) {
                    revert NoWhitespaceAfterUsingWordsFrom(state.parseErrorOffset(cursor));
                }
                ++cursor;
            }

            while (cursor < end) {
                // It's fine to add comments for each pragma address.
                // This also has the effect of moving past the interstitial after
                // the last address as we don't break til just below.
                cursor = state.parseInterstitial(cursor, end);

                // parseInterstitial may have consumed trailing whitespace
                // up to end. Must re-check before tryParseLiteral, which
                // does mload(cursor) and would read past bounds.
                if (cursor >= end) {
                    break;
                }

                // Try to parse a literal and treat it as an address.
                bool success;
                bytes32 value;
                (success, cursor, value) = state.tryParseLiteral(cursor, end);
                // If we didn't parse a literal, we're done with the pragma.
                if (!success) {
                    break;
                } else {
                    state.pushSubParser(cursor, value);
                }
            }

            return cursor;
        }
    }
}
