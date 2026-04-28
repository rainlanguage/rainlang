// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {
    CMASK_STRING_LITERAL_HEAD,
    CMASK_LITERAL_HEX_DISPATCH,
    CMASK_NUMERIC_LITERAL_HEAD,
    CMASK_SUB_PARSEABLE_LITERAL_HEAD,
    CMASK_ZERO,
    CMASK_UPPER_X
} from "rain.string/lib/parse/LibParseCMask.sol";

import {UnsupportedLiteralType, UppercaseHexPrefix} from "../../../error/ErrParse.sol";
import {ParseState} from "../LibParseState.sol";
import {LibParseError} from "../LibParseError.sol";

/// @dev The number of built-in literal parser types.
uint256 constant LITERAL_PARSERS_LENGTH = 4;

/// @dev Index of the hexadecimal literal parser (e.g. `0xDEAD`).
uint256 constant LITERAL_PARSER_INDEX_HEX = 0;
/// @dev Index of the decimal literal parser (e.g. `42`, `1e18`).
uint256 constant LITERAL_PARSER_INDEX_DECIMAL = 1;
/// @dev Index of the string literal parser (e.g. `"hello"`).
uint256 constant LITERAL_PARSER_INDEX_STRING = 2;
/// @dev Index of the sub-parseable literal parser (e.g. `[dispatch body]`).
uint256 constant LITERAL_PARSER_INDEX_SUB_PARSE = 3;

/// @title LibParseLiteral
/// @notice Dispatches literal parsing to the appropriate type-specific parser
/// (hex, decimal, string, or sub-parseable) based on the head character.
library LibParseLiteral {
    using LibParseLiteral for ParseState;
    using LibParseError for ParseState;

    /// @notice Selects a literal parser function pointer from the state's literal
    /// parsers array by index. Not bounds checked as indexes are expected to
    /// be provided by the parser itself.
    /// @param state The current parse state.
    /// @param index The index of the literal parser to select.
    /// @return The selected literal parser function pointer.
    function selectLiteralParserByIndex(ParseState memory state, uint256 index)
        internal
        pure
        returns (function(ParseState memory, uint256, uint256) view returns (uint256, bytes32))
    {
        bytes memory literalParsers = state.literalParsers;
        function(ParseState memory, uint256, uint256) view returns (uint256, bytes32) parser;
        // This is NOT bounds checked because the indexes are all expected to
        // be provided by the parser itself and not user input.
        assembly ("memory-safe") {
            parser := and(mload(add(literalParsers, add(2, mul(index, 2)))), 0xFFFF)
        }
        return parser;
    }

    /// @notice Parses a literal value at the cursor position. Reverts with
    /// `UnsupportedLiteralType` if the literal type cannot be determined.
    /// @param state The current parse state.
    /// @param cursor The current cursor position in the source string.
    /// @param end The end of the source string.
    /// @return The updated cursor position after parsing.
    /// @return The parsed literal value.
    function parseLiteral(ParseState memory state, uint256 cursor, uint256 end)
        internal
        view
        returns (uint256, bytes32)
    {
        (bool success, uint256 newCursor, bytes32 value) = tryParseLiteral(state, cursor, end);
        if (success) {
            return (newCursor, value);
        } else {
            revert UnsupportedLiteralType(state.parseErrorOffset(cursor));
        }
    }

    /// @notice Attempts to parse a literal value at the cursor position. Dispatches
    /// to hex, decimal, string, or sub-parseable parsers based on the head
    /// character. Returns false if the literal type is not recognized.
    /// @param state The current parse state.
    /// @param cursor The current cursor position in the source string.
    /// @param end The end of the source string.
    /// @return Whether a literal was successfully parsed.
    /// @return The updated cursor position after parsing.
    /// @return The parsed literal value.
    function tryParseLiteral(ParseState memory state, uint256 cursor, uint256 end)
        internal
        view
        returns (bool, uint256, bytes32)
    {
        uint256 index;
        {
            uint256 word;
            uint256 head;
            assembly ("memory-safe") {
                word := mload(cursor)
                //slither-disable-next-line incorrect-shift
                head := shl(byte(0, word), 1)
            }

            // Figure out the literal type and dispatch to the correct parser.
            // Probably a numeric, most things are.
            if ((head & CMASK_NUMERIC_LITERAL_HEAD) != 0) {
                // Only read the second byte for hex disambiguation if it
                // exists within the source bounds. If the numeric literal is
                // the last byte of the source, default to decimal — reading
                // past end would pick up adjacent memory that could
                // coincidentally be 'x' (0x78).
                if (cursor + 1 < end) {
                    uint256 disambiguate;
                    assembly ("memory-safe") {
                        //slither-disable-next-line incorrect-shift
                        disambiguate := shl(byte(1, word), 1)
                    }
                    // Hexadecimal literal dispatch is 0x. We can't accidentally
                    // match x0 because we already checked that the head is 0-9.
                    if ((head | disambiguate) == CMASK_LITERAL_HEX_DISPATCH) {
                        index = LITERAL_PARSER_INDEX_HEX;
                    }
                    // Uppercase 0X is not valid — revert explicitly rather
                    // than silently parsing as decimal zero.
                    else if ((head | disambiguate) == (CMASK_ZERO | CMASK_UPPER_X)) {
                        revert UppercaseHexPrefix(state.parseErrorOffset(cursor));
                    } else {
                        index = LITERAL_PARSER_INDEX_DECIMAL;
                    }
                } else {
                    index = LITERAL_PARSER_INDEX_DECIMAL;
                }
            }
            // Could be a lil' string.
            else if ((head & CMASK_STRING_LITERAL_HEAD) != 0) {
                index = LITERAL_PARSER_INDEX_STRING;
            }
            // Or a sub parseable something.
            else if ((head & CMASK_SUB_PARSEABLE_LITERAL_HEAD) != 0) {
                index = LITERAL_PARSER_INDEX_SUB_PARSE;
            }
            // We don't know what this is.
            else {
                return (false, cursor, 0);
            }
        }
        bytes32 value;
        (cursor, value) = state.selectLiteralParserByIndex(index)(state, cursor, end);
        return (true, cursor, value);
    }
}
