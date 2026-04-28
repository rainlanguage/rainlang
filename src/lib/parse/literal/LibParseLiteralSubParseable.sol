// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ParseState} from "../LibParseState.sol";
import {LibParse} from "../LibParse.sol";
import {UnclosedSubParseableLiteral, SubParseableMissingDispatch} from "../../../error/ErrParse.sol";
import {CMASK_WHITESPACE, CMASK_SUB_PARSEABLE_LITERAL_END} from "rain.string/lib/parse/LibParseCMask.sol";
import {LibParseInterstitial} from "../LibParseInterstitial.sol";
import {LibParseError} from "../LibParseError.sol";
import {LibSubParse} from "../LibSubParse.sol";
import {LibParseChar} from "rain.string/lib/parse/LibParseChar.sol";

/// @title LibParseLiteralSubParseable
/// @notice Parses sub-parseable literals delimited by `[` and `]` by
/// delegating to registered sub-parser contracts.
library LibParseLiteralSubParseable {
    using LibParse for ParseState;
    using LibParseInterstitial for ParseState;
    using LibParseError for ParseState;
    using LibSubParse for ParseState;

    /// @notice Parse a sub parseable literal. All sub parseable literals are bounded by
    /// square brackets, and contain a dispatch and a body. The dispatch is the
    /// string immediately following the opening bracket, and the body is the
    /// string immediately following the dispatch, up to the closing bracket.
    /// The dispatch and body MUST be separated by at least one whitespace char.
    /// This implies that the dispatch MAY NOT contain any whitespace chars, and
    /// the body MAY contain any chars except for the closing bracket.
    /// Leading and trailing whitespace before/after the dispatch/body is NOT
    /// supported. The former will error and the latter will be treated as part
    /// of the body.
    /// @param state The current parse state.
    /// @param cursor The cursor position at the opening bracket.
    /// @param end The end of the source string.
    /// @return The updated cursor position after parsing.
    /// @return The parsed literal value.
    function parseSubParseable(ParseState memory state, uint256 cursor, uint256 end)
        internal
        view
        returns (uint256, bytes32)
    {
        unchecked {
            // Move cursor past opening bracket.
            // Caller is responsible for checking that the cursor is pointing
            // at a sub parseable literal.
            ++cursor;

            uint256 dispatchStart = cursor;

            // Skip all non-whitespace and non-bracket characters.
            cursor = LibParseChar.skipMask(cursor, end, ~(CMASK_WHITESPACE | CMASK_SUB_PARSEABLE_LITERAL_END));
            uint256 dispatchEnd = cursor;

            if (dispatchEnd == dispatchStart) {
                revert SubParseableMissingDispatch(state.parseErrorOffset(cursor));
            }

            // Skip any whitespace.
            cursor = state.skipWhitespace(cursor, end);

            uint256 bodyStart = cursor;

            // Skip all chars til the close. Each byte is checked independently
            // against the mask — multibyte encodings are not understood. A byte
            // in a multibyte sequence that equals `]` (0x5D) would stop the
            // scan prematurely. This cannot happen in valid UTF-8 (continuation
            // bytes are 0x80-0xBF), but is possible in other encodings.
            cursor = LibParseChar.skipMask(cursor, end, ~CMASK_SUB_PARSEABLE_LITERAL_END);
            uint256 bodyEnd = cursor;

            if (cursor >= end) {
                revert UnclosedSubParseableLiteral(state.parseErrorOffset(cursor));
            }
            {
                uint256 finalChar;
                assembly ("memory-safe") {
                    //slither-disable-next-line incorrect-shift
                    finalChar := shl(byte(0, mload(cursor)), 1)
                }
                if ((finalChar & CMASK_SUB_PARSEABLE_LITERAL_END) == 0) {
                    revert UnclosedSubParseableLiteral(state.parseErrorOffset(cursor));
                }
            }

            // Move cursor past closing bracket.
            ++cursor;

            return (cursor, state.subParseLiteral(dispatchStart, dispatchEnd, bodyStart, bodyEnd));
        }
    }
}
