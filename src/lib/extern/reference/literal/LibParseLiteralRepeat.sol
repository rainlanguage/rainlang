// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @title LibParseLiteralRepeat
/// @notice This is a library that mimics the literal libraries elsewhere in this repo,
/// but structured to fit sub parsing rather than internal logic. It is NOT
/// required to use this pattern, of libs outside the implementation contract,
/// but it MAY be convenient to do so, as the libs can be moved to dedicated
/// files, easily tested and reviewed directly, etc.
///
/// This literal parser is a simple repeat literal parser. It is extremely
/// contrived and serves no real world purpose. It is used to demonstrate how
/// to implement a literal parser, including extracting a value from the
/// dispatch data and providing it to the parser.
///
/// The repeat literal parser takes a single digit as input, and repeats that
/// digit for every byte in the literal.
/// ```
/// /* 000 */
/// [ref-extern-repeat-0 abc]
/// /* 111 */
/// [ref-extern-repeat-1 cde]
/// /* 222 */
/// [ref-extern-repeat-2 zzz]
/// /* 333 */
/// [ref-extern-repeat-3 123]
/// ```

/// @dev The maximum length of a repeat literal body (exclusive). Length must
/// be strictly less than this value. For length 77 the worst-case accumulation
/// is 10^77 - 1, which fits in uint256 (10^77 < 2^256). Length 78 would
/// accumulate up to 10^78 - 1, which overflows (10^78 > 2^256).
uint256 constant MAX_REPEAT_LITERAL_LENGTH = 78;

/// @dev Thrown when a repeat literal body exceeds the maximum length that can
/// be computed without overflow in `10 ** i`.
/// @param length The length of the literal body.
error RepeatLiteralTooLong(uint256 length);

/// @dev Thrown when the dispatch value is not a single decimal digit.
/// @param dispatchValue The invalid dispatch value.
error RepeatDispatchNotDigit(uint256 dispatchValue);

library LibParseLiteralRepeat {
    /// @notice Parses a repeat literal by repeating the dispatch digit for every
    /// byte in the literal body.
    /// @param dispatchValue The single decimal digit to repeat (0-9).
    /// @param cursor Pointer to the start of the literal body.
    /// @param end Pointer to the end of the literal body.
    /// @return The computed repeated value.
    //slither-disable-next-line dead-code
    function parseRepeat(uint256 dispatchValue, uint256 cursor, uint256 end) internal pure returns (uint256) {
        if (dispatchValue > 9) {
            revert RepeatDispatchNotDigit(dispatchValue);
        }
        unchecked {
            uint256 value = 0;
            // Safe: cursor always <= end (parser invariant).
            uint256 length = end - cursor;
            if (length >= MAX_REPEAT_LITERAL_LENGTH) {
                revert RepeatLiteralTooLong(length);
            }
            for (uint256 i = 0; i < length; ++i) {
                // Safe: i <= 76, so 10**i <= 10**76 < 2^256.
                // dispatchValue <= 9, so dispatchValue * 10**i <= 9 * 10**76 < 2^256.
                // value accumulates at most 77 terms, sum <= 10**77 - 1 < 2^256.
                value += dispatchValue * 10 ** i;
            }
            return value;
        }
    }
}
