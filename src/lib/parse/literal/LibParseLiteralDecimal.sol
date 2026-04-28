// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ParseState} from "../LibParseState.sol";
import {LibParseError} from "../LibParseError.sol";
import {LibParseDecimalFloat, Float} from "rain.math.float/lib/parse/LibParseDecimalFloat.sol";
import {LibDecimalFloat} from "rain.math.float/lib/LibDecimalFloat.sol";

/// @title LibParseLiteralDecimal
/// @notice Parses decimal numeric literals from Rainlang source text into
/// packed decimal float values.
library LibParseLiteralDecimal {
    using LibParseError for ParseState;

    /// @notice Parses a decimal float literal from the source and returns it as a
    /// losslessly packed float in bytes32 form.
    /// @param state The current parse state.
    /// @param start The cursor position at the start of the literal.
    /// @param end The end of the source string.
    /// @return The updated cursor position after parsing.
    /// @return The parsed decimal float as a packed bytes32.
    function parseDecimalFloatPacked(ParseState memory state, uint256 start, uint256 end)
        internal
        pure
        returns (uint256, bytes32)
    {
        (bytes4 errorSelector, uint256 cursor, int256 signedCoefficient, int256 exponent) =
            LibParseDecimalFloat.parseDecimalFloatInline(start, end);
        state.handleErrorSelector(cursor, errorSelector);
        return (cursor, Float.unwrap(LibDecimalFloat.packLossless(signedCoefficient, exponent)));
    }
}
