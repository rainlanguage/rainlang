// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {
    ExpectedOperand,
    UnclosedOperand,
    OperandValuesOverflow,
    UnexpectedOperand,
    UnexpectedOperandValue,
    OperandOverflow
} from "../../error/ErrParse.sol";
import {OperandV2} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibParseLiteral} from "./literal/LibParseLiteral.sol";
import {CMASK_OPERAND_END, CMASK_WHITESPACE, CMASK_OPERAND_START} from "rain.string/lib/parse/LibParseCMask.sol";
import {ParseState, OPERAND_VALUES_LENGTH, FSM_YANG_MASK} from "./LibParseState.sol";
import {LibParseError} from "./LibParseError.sol";
import {LibParseInterstitial} from "./LibParseInterstitial.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";

/// @title LibParseOperand
/// @notice Parses operand values from Rainlang source text and dispatches
/// to type-specific operand handlers.
library LibParseOperand {
    using LibParseError for ParseState;
    using LibParseLiteral for ParseState;
    using LibParseOperand for ParseState;
    using LibParseInterstitial for ParseState;
    using LibDecimalFloat for Float;

    /// @notice Parses an operand from the source string at the cursor position,
    /// extracting literal values between the operand delimiters into the
    /// state's operandValues array.
    /// @param state The current parse state.
    /// @param cursor The current cursor position in the source string.
    /// @param end The end of the source string.
    /// @return The updated cursor position after parsing the operand.
    function parseOperand(ParseState memory state, uint256 cursor, uint256 end) internal view returns (uint256) {
        uint256 char;
        assembly ("memory-safe") {
            //slither-disable-next-line incorrect-shift
            char := shl(byte(0, mload(cursor)), 1)
        }

        // Reset operand values to length 0 to avoid any previous values bleeding
        // into processing this operand.
        bytes32[] memory operandValues = state.operandValues;
        assembly ("memory-safe") {
            mstore(operandValues, 0)
        }

        // There may not be an operand. Only process if there is.
        if (char == CMASK_OPERAND_START) {
            // Move past the opening character.
            ++cursor;
            // Let the state be yin so we can parse literals.
            state.fsm &= ~FSM_YANG_MASK;

            // Load the next char.
            assembly ("memory-safe") {
                //slither-disable-next-line incorrect-shift
                char := shl(byte(0, mload(cursor)), 1)
            }
            uint256 i = 0;
            bool success = false;
            while (cursor < end) {
                // Load the next char.
                assembly ("memory-safe") {
                    //slither-disable-next-line incorrect-shift
                    char := shl(byte(0, mload(cursor)), 1)
                }

                // Handle any whitespace.
                // We DO NOT currently support full interstitial parsing here.
                if (char & CMASK_WHITESPACE != 0) {
                    // Move past the whitespace.
                    cursor = state.skipWhitespace(cursor, end);
                }
                // If the operand has ended break.
                else if (char & CMASK_OPERAND_END != 0) {
                    // Move past the operand end.
                    ++cursor;
                    success = true;
                    break;
                }
                // Attempt to parse literals if we're not yang.
                else if (state.fsm & FSM_YANG_MASK == 0) {
                    // We can't exceed the initial length of the operand values
                    // that was allocated when the parse state was created.
                    if (i == OPERAND_VALUES_LENGTH) {
                        revert OperandValuesOverflow(state.parseErrorOffset(cursor));
                    }
                    bytes32 value;
                    (cursor, value) = state.parseLiteral(cursor, end);
                    // We manipulate the operand values array directly in
                    // assembly because if we used the Solidity indexing syntax
                    // it would bounds check against the _current_ length of the
                    // operand values array, not the length it was when the
                    // parse state was created. The current length is just
                    // whatever it happened to be for the last operand that was
                    // parsed, so it's not useful for us here.
                    assembly ("memory-safe") {
                        mstore(add(operandValues, add(0x20, mul(i, 0x20))), value)
                    }
                    // Set yang so we don't attempt to parse a literal straight
                    // off the back of this literal without some whitespace.
                    state.fsm |= FSM_YANG_MASK;
                    ++i;
                }
                // Something failed here so let's say the author forgot to close
                // the operand, which is a little arbitrary but at least it's
                // a consistent error.
                else {
                    revert UnclosedOperand(state.parseErrorOffset(cursor));
                }
            }
            if (!success) {
                revert UnclosedOperand(state.parseErrorOffset(cursor));
            }
            assembly ("memory-safe") {
                mstore(operandValues, i)
            }
        }

        return cursor;
    }

    /// @notice Standard dispatch for handling an operand after it is parsed, using the
    /// encoded function pointers on the current parse state. Requires that the
    /// word index has been looked up by the parser, exists, and the literal
    /// values have all been parsed out of the operand string. In the case of
    /// the main parser this will all be done inline, but in the case of a sub
    /// parser the literal extraction will be done first, then the word lookup
    /// will have to be done by the sub parser, alongside the values provided
    /// by the main parser.
    /// @param state The current parse state.
    /// @param wordIndex The index of the word in the parse state's word list.
    /// @return The operand constructed by the handler for the given word.
    function handleOperand(ParseState memory state, uint256 wordIndex) internal pure returns (OperandV2) {
        function(bytes32[] memory) internal pure returns (OperandV2) handler;
        bytes memory handlers = state.operandHandlers;
        assembly ("memory-safe") {
            // There is no bounds check here because the indexes are calculated
            // by the parser itself, NOT provided by the user. Therefore the
            // scope of corrupt data is limited to a bug in the parser itself,
            // which can and should have direct test coverage.
            handler := and(mload(add(handlers, add(2, mul(wordIndex, 2)))), 0xFFFF)
        }
        return handler(state.operandValues);
    }

    /// @notice Operand handler that disallows any operand values. Reverts if any
    /// values are provided, otherwise returns a zero operand.
    /// @param values The parsed operand values from the source string.
    /// @return The zero operand.
    function handleOperandDisallowed(bytes32[] memory values) internal pure returns (OperandV2) {
        if (values.length != 0) {
            revert UnexpectedOperand();
        }
        return OperandV2.wrap(0);
    }

    /// @notice Operand handler that disallows any operand values but always returns
    /// an operand of 1 instead of 0.
    /// @param values The parsed operand values from the source string.
    /// @return The operand with a constant value of 1.
    function handleOperandDisallowedAlwaysOne(bytes32[] memory values) internal pure returns (OperandV2) {
        if (values.length != 0) {
            revert UnexpectedOperand();
        }
        return OperandV2.wrap(bytes32(uint256(1)));
    }

    /// @notice There must be one or zero values. The fallback is 0 if nothing is
    /// provided, else the provided Float value is converted to a lossless
    /// integer and MUST fit in a uint16.
    /// @param values The parsed operand values from the source string.
    /// @return operand The single full operand, defaulting to 0 if not
    /// provided.
    function handleOperandSingleFull(bytes32[] memory values) internal pure returns (OperandV2 operand) {
        // Happy path at the top for efficiency.
        if (values.length == 1) {
            assembly ("memory-safe") {
                operand := mload(add(values, 0x20))
            }
            (int256 signedCoefficient, int256 exponent) = Float.wrap(OperandV2.unwrap(operand)).unpack();
            uint256 operandUint = LibDecimalFloat.toFixedDecimalLossless(signedCoefficient, exponent, 0);
            if (operandUint > type(uint16).max) {
                revert OperandOverflow();
            }
            operand = OperandV2.wrap(bytes32(operandUint));
        } else if (values.length == 0) {
            operand = OperandV2.wrap(0);
        } else {
            revert UnexpectedOperandValue();
        }
    }

    /// @notice There must be exactly one value. There is no default fallback. The
    /// provided Float value is converted to a lossless integer and MUST fit
    /// in a uint16.
    /// @param values The parsed operand values from the source string.
    /// @return operand The single full operand with no default.
    function handleOperandSingleFullNoDefault(bytes32[] memory values) internal pure returns (OperandV2 operand) {
        // Happy path at the top for efficiency.
        if (values.length == 1) {
            assembly ("memory-safe") {
                operand := mload(add(values, 0x20))
            }
            (int256 signedCoefficient, int256 exponent) = Float.wrap(OperandV2.unwrap(operand)).unpack();
            uint256 operandUint = LibDecimalFloat.toFixedDecimalLossless(signedCoefficient, exponent, 0);
            if (operandUint > type(uint16).max) {
                revert OperandOverflow();
            }
            operand = OperandV2.wrap(bytes32(operandUint));
        } else if (values.length == 0) {
            revert ExpectedOperand();
        } else {
            revert UnexpectedOperandValue();
        }
    }

    /// @notice There must be exactly two values. There is no default fallback. Each
    /// Float value is converted to a lossless integer and MUST fit in a
    /// uint8. Packed as `a | (b << 8)`.
    /// @param values The parsed operand values from the source string.
    /// @return operand The double-per-byte operand with no default.
    function handleOperandDoublePerByteNoDefault(bytes32[] memory values) internal pure returns (OperandV2 operand) {
        // Happy path at the top for efficiency.
        if (values.length == 2) {
            Float a;
            Float b;
            assembly ("memory-safe") {
                a := mload(add(values, 0x20))
                b := mload(add(values, 0x40))
            }
            // slither-disable-next-line write-after-write
            (int256 signedCoefficient, int256 exponent) = LibDecimalFloat.unpack(a);
            uint256 aUint = LibDecimalFloat.toFixedDecimalLossless(signedCoefficient, exponent, 0);
            (signedCoefficient, exponent) = LibDecimalFloat.unpack(b);
            uint256 bUint = LibDecimalFloat.toFixedDecimalLossless(signedCoefficient, exponent, 0);

            if (aUint > type(uint8).max || bUint > type(uint8).max) {
                revert OperandOverflow();
            }

            operand = OperandV2.wrap(bytes32(aUint | (bUint << 8)));
        } else if (values.length < 2) {
            revert ExpectedOperand();
        } else {
            revert UnexpectedOperandValue();
        }
    }

    /// @notice 8 bit value then maybe 1 bit flag then maybe 1 bit flag. Fallback to 0
    /// for both flags if not provided. Packed as `a | (b << 8) | (c << 9)`.
    /// @param values The parsed operand values from the source string.
    /// @return operand The operand encoding an 8-bit value and two optional
    /// 1-bit flags.
    //forge-lint: disable-next-line(mixed-case-function)
    function handleOperand8M1M1(bytes32[] memory values) internal pure returns (OperandV2 operand) {
        // Happy path at the top for efficiency.
        uint256 length = values.length;
        if (length >= 1 && length <= 3) {
            Float a;
            Float b;
            Float c;
            assembly ("memory-safe") {
                a := mload(add(values, 0x20))
            }

            if (length >= 2) {
                assembly ("memory-safe") {
                    b := mload(add(values, 0x40))
                }
            } else {
                b = Float.wrap(0);
            }

            if (length == 3) {
                assembly ("memory-safe") {
                    c := mload(add(values, 0x60))
                }
            } else {
                c = Float.wrap(0);
            }

            // slither-disable-next-line write-after-write
            (int256 signedCoefficient, int256 exponent) = LibDecimalFloat.unpack(a);
            uint256 aUint = LibDecimalFloat.toFixedDecimalLossless(signedCoefficient, exponent, 0);
            (signedCoefficient, exponent) = LibDecimalFloat.unpack(b);
            uint256 bUint = LibDecimalFloat.toFixedDecimalLossless(signedCoefficient, exponent, 0);
            (signedCoefficient, exponent) = LibDecimalFloat.unpack(c);
            uint256 cUint = LibDecimalFloat.toFixedDecimalLossless(signedCoefficient, exponent, 0);

            if (aUint > type(uint8).max || bUint > 1 || cUint > 1) {
                revert OperandOverflow();
            }

            operand = OperandV2.wrap(bytes32(aUint | (bUint << 8) | (cUint << 9)));
        } else if (length == 0) {
            revert ExpectedOperand();
        } else {
            revert UnexpectedOperandValue();
        }
    }

    /// @notice 2x maybe 1 bit flags. Fallback to 0 for both flags if not provided.
    /// Packed as `a | (b << 1)`.
    /// @param values The parsed operand values from the source string.
    /// @return operand The operand encoding two optional 1-bit flags.
    //forge-lint: disable-next-line(mixed-case-function)
    function handleOperandM1M1(bytes32[] memory values) internal pure returns (OperandV2 operand) {
        // Happy path at the top for efficiency.
        uint256 length = values.length;
        if (length < 3) {
            Float a;
            Float b;

            if (length >= 1) {
                assembly ("memory-safe") {
                    a := mload(add(values, 0x20))
                }
            } else {
                a = Float.wrap(0);
            }

            if (length == 2) {
                assembly ("memory-safe") {
                    b := mload(add(values, 0x40))
                }
            } else {
                b = Float.wrap(0);
            }

            // slither-disable-next-line write-after-write
            (int256 signedCoefficient, int256 exponent) = LibDecimalFloat.unpack(a);
            uint256 aUint = LibDecimalFloat.toFixedDecimalLossless(signedCoefficient, exponent, 0);
            (signedCoefficient, exponent) = LibDecimalFloat.unpack(b);
            uint256 bUint = LibDecimalFloat.toFixedDecimalLossless(signedCoefficient, exponent, 0);

            if (aUint > 1 || bUint > 1) {
                revert OperandOverflow();
            }

            operand = OperandV2.wrap(bytes32(aUint | (bUint << 1)));
        } else {
            revert UnexpectedOperandValue();
        }
    }
}
