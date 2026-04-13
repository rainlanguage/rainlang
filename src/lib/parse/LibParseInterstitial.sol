// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {FSM_YANG_MASK, ParseState} from "./LibParseState.sol";
import {
    CMASK_COMMENT_HEAD,
    CMASK_WHITESPACE,
    COMMENT_END_SEQUENCE,
    COMMENT_START_SEQUENCE,
    CMASK_COMMENT_END_SEQUENCE_END
} from "rain.string/lib/parse/LibParseCMask.sol";
import {MalformedCommentStart, UnclosedComment} from "../../error/ErrParse.sol";
import {LibParseError} from "./LibParseError.sol";
import {LibParseChar} from "rain.string/lib/parse/LibParseChar.sol";

/// @dev Shift to extract a packed 2-byte comment delimiter sequence from the
/// high bits of a 256-bit mload.
uint256 constant COMMENT_SEQUENCE_SHIFT = 0xf0;

/// @title LibParseInterstitial
/// @notice Handles whitespace and comment skipping between meaningful tokens
/// during parsing.
library LibParseInterstitial {
    using LibParseError for ParseState;
    using LibParseInterstitial for ParseState;

    /// @notice The cursor currently points at the head of a comment. We need to skip
    /// over all data until we find the end of the comment. This MAY REVERT if
    /// the comment is malformed, e.g. if the comment doesn't start with `/*`.
    /// @param state The parser state.
    /// @param cursor The current cursor position.
    /// @param end The end of the data to parse.
    /// @return The new cursor position after the comment.
    function skipComment(ParseState memory state, uint256 cursor, uint256 end) internal pure returns (uint256) {
        // Set yang for comments to force a little breathing room between
        // comments and the next item.
        state.fsm |= FSM_YANG_MASK;

        // We're going to ignore overflow here because if either cursor or
        // end is anywhere near uint256 max something went very wrong
        // elsewhere already.
        unchecked {
            // It's an error if we can't fit the comment sequences in the
            // remaining data to parse.
            if (cursor + 4 > end) {
                revert UnclosedComment(state.parseErrorOffset(cursor));
            }

            // First check the comment opening sequence is not malformed.
            uint256 startSequence;
            assembly ("memory-safe") {
                startSequence := shr(COMMENT_SEQUENCE_SHIFT, mload(cursor))
            }
            if (startSequence != COMMENT_START_SEQUENCE) {
                revert MalformedCommentStart(state.parseErrorOffset(cursor));
            }

            // Move past the start sequence.
            // The 3rd character can never be the end of the comment.
            // Consider the string /*/ which is not a valid comment.
            cursor += 3;

            bool foundEnd = false;
            while (cursor < end) {
                uint256 charByte;
                assembly ("memory-safe") {
                    charByte := byte(0, mload(cursor))
                }
                if (charByte == CMASK_COMMENT_END_SEQUENCE_END) {
                    // Maybe this is the end of the comment.
                    // Check the sequence.
                    uint256 endSequence;
                    assembly ("memory-safe") {
                        endSequence := shr(COMMENT_SEQUENCE_SHIFT, mload(sub(cursor, 1)))
                    }
                    if (endSequence == COMMENT_END_SEQUENCE) {
                        // We found the end of the comment.
                        // Move past the end sequence and stop looping.
                        ++cursor;
                        foundEnd = true;
                        break;
                    }
                }
                ++cursor;
            }

            // If we didn't find the end of the comment, it's an error.
            if (!foundEnd) {
                revert UnclosedComment(state.parseErrorOffset(cursor));
            }

            return cursor;
        }
    }

    /// @notice Advances the cursor past any contiguous whitespace characters and
    /// resets the FSM to yin state.
    /// @param state The parser state.
    /// @param cursor The current cursor position.
    /// @param end The end of the data to parse.
    /// @return The new cursor position after the whitespace.
    function skipWhitespace(ParseState memory state, uint256 cursor, uint256 end) internal pure returns (uint256) {
        unchecked {
            // Set ying as we now open to possibilities.
            state.fsm &= ~FSM_YANG_MASK;
            return LibParseChar.skipMask(cursor, end, CMASK_WHITESPACE);
        }
    }

    /// @notice Skips over all interstitial content (whitespace and comments) between
    /// meaningful parse tokens, returning the cursor at the next non-interstitial
    /// character.
    /// @param state The parser state.
    /// @param cursor The current cursor position.
    /// @param end The end of the data to parse.
    /// @return The new cursor position after all interstitial content.
    function parseInterstitial(ParseState memory state, uint256 cursor, uint256 end) internal pure returns (uint256) {
        while (cursor < end) {
            uint256 char;
            assembly ("memory-safe") {
                //slither-disable-next-line incorrect-shift
                char := shl(byte(0, mload(cursor)), 1)
            }
            if (char & CMASK_WHITESPACE > 0) {
                cursor = state.skipWhitespace(cursor, end);
            } else if (char & CMASK_COMMENT_HEAD > 0) {
                cursor = state.skipComment(cursor, end);
            } else {
                break;
            }
        }
        return cursor;
    }
}
