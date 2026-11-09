// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {LibParseState, ParseState} from "./LibParseState.sol";
import {CMASK_WHITESPACE} from "rain-string-0.3.9/src/lib/parse/LibParseCMask.sol";
import {NoWhitespaceAfterUsingWordsFrom} from "../../error/ErrParse.sol";
import {LibParseError} from "./LibParseError.sol";
import {LibParseInterstitial} from "./LibParseInterstitial.sol";
import {LibParseLiteral} from "./literal/LibParseLiteral.sol";
import {LibParseSprite, PARSE_SPRITE, PARSE_SPRITE_PRAGMA_KEYWORD} from "./LibParseSprite.sol";

/// @dev The raw bytes of the pragma keyword "using-words-from".
bytes constant PRAGMA_KEYWORD_BYTES = bytes("using-words-from");
/// @dev The byte length of the pragma keyword (16 bytes for "using-words-from").
uint256 constant PRAGMA_KEYWORD_BYTES_LENGTH = PARSE_SPRITE_PRAGMA_KEYWORD & 0xFF;

/// @title LibParsePragma
/// @notice Parses the `using-words-from` pragma from Rainlang source text
/// and registers sub-parser contract addresses on the parse state.
///
/// @dev Sub-parsers are external contracts called during parse to resolve
/// words this parser doesn't recognise. They are invoked at parse time,
/// receive parser state context, and return bytecode that is spliced
/// into the result. `integrityCheck2` then validates the assembled
/// bytecode's structural and stack-tracking correctness.
///
/// Trust model: sub-parsers run under the same trust assumption as the
/// expression author. A buggy or malicious sub-parser can:
/// - emit syntactically valid bytecode that nevertheless encodes
///   behaviour the user did not write (e.g. wrong opcode index, swapped
///   inputs);
/// - emit constants of its choosing, including ones that look like
///   addresses the user did not specify;
/// - decline to parse legitimate input and revert the entire expression.
///
/// The integrity check on the assembled bytecode catches stack-shape and
/// pointer-bounds violations. It does NOT verify semantic equivalence
/// between the source text and the bytecode the sub-parser produced —
/// that's a function of the sub-parser's correctness, not the
/// interpreter's.
///
/// Integrators MUST vet every sub-parser address they accept (or that
/// users include via the `using-words-from` pragma) under the same trust
/// model they apply to the expression itself. An expression with a
/// hostile sub-parser is equivalent to a hostile expression.
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
            // Bail without modifying the cursor if there's no pragma.
            if (!LibParseSprite.regionEquals(
                    PARSE_SPRITE, cursor, cursor + PRAGMA_KEYWORD_BYTES_LENGTH, PARSE_SPRITE_PRAGMA_KEYWORD
                )) {
                return cursor;
            }

            {
                // Move past the pragma keyword.
                cursor += PRAGMA_KEYWORD_BYTES_LENGTH;

                // If the input ends exactly at the keyword there is no
                // whitespace char to read.
                if (cursor >= end) {
                    state.revertParseError(cursor, NoWhitespaceAfterUsingWordsFrom.selector);
                }

                // Need at least one whitespace char after the pragma keyword.
                uint256 char;
                assembly ("memory-safe") {
                    //slither-disable-next-line incorrect-shift
                    char := shl(byte(0, mload(cursor)), 1)
                }
                if (char & CMASK_WHITESPACE == 0) {
                    state.revertParseError(cursor, NoWhitespaceAfterUsingWordsFrom.selector);
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
