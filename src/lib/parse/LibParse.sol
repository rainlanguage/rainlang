// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {LibPointer, Pointer} from "rain.solmem/lib/LibPointer.sol";
import {LibMemCpy} from "rain.solmem/lib/LibMemCpy.sol";
import {
    CMASK_COMMENT_HEAD,
    CMASK_EOS,
    CMASK_EOL,
    CMASK_LITERAL_HEAD,
    CMASK_WHITESPACE,
    CMASK_RIGHT_PAREN,
    CMASK_LEFT_PAREN,
    CMASK_RHS_WORD_TAIL,
    CMASK_RHS_WORD_HEAD,
    CMASK_LHS_RHS_DELIMITER,
    CMASK_LHS_STACK_TAIL,
    CMASK_LHS_STACK_HEAD,
    CMASK_IDENTIFIER_HEAD
} from "rain.string/lib/parse/LibParseCMask.sol";
import {LibParseChar} from "rain.string/lib/parse/LibParseChar.sol";
import {LibParseMeta} from "rain.interpreter.interface/lib/parse/LibParseMeta.sol";
import {LibParseOperand} from "./LibParseOperand.sol";
import {OperandV2, OPCODE_STACK, OPCODE_UNKNOWN} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibParseStackName} from "./LibParseStackName.sol";
import {
    UnexpectedRHSChar,
    UnexpectedRightParen,
    WordSize,
    DuplicateLHSItem,
    ParserOutOfBounds,
    ExpectedLeftParen,
    UnexpectedLHSChar,
    MissingFinalSemi,
    UnexpectedComment,
    ParenOverflow,
    LHSItemCountOverflow
} from "../../error/ErrParse.sol";
import {
    LibParseState,
    ParseState,
    FSM_YANG_MASK,
    FSM_DEFAULT,
    FSM_ACTIVE_SOURCE_MASK,
    FSM_WORD_END_MASK,
    PARSE_STATE_PAREN_TRACKER0_OFFSET
} from "./LibParseState.sol";
import {LibParsePragma} from "./LibParsePragma.sol";
import {LibParseInterstitial} from "./LibParseInterstitial.sol";
import {LibParseError} from "./LibParseError.sol";
import {LibSubParse} from "./LibSubParse.sol";
import {LibBytes} from "rain.solmem/lib/LibBytes.sol";
import {LibBytes32Array} from "rain.solmem/lib/LibBytes32Array.sol";

/// @dev Size in bytes of the fixed header prepended to sub-parser bytecode.
/// Comprises the operand values tail pointer (2 bytes), the literal parsers
/// tail pointer (2 bytes), and the word length (1 byte).
uint256 constant SUB_PARSER_BYTECODE_HEADER_SIZE = 5;

/// @dev Maximum paren offset before the paren tracker overflows. The tracker
/// has 62 bytes of group data (3 bytes each, fitting 20 groups), but
/// `pushOpToSource` writes a phantom counter at `parenOffset + 4`, so the
/// effective limit is 19 groups (offset 57). The check rejects offset 60
/// because `newParenOffset` is already incremented by 3.
uint256 constant MAX_PAREN_OFFSET = 59;

/// @title LibParse
/// @notice Core parsing library for Rainlang source text.
///
/// The parser only supports single-byte ASCII input. All character masks are
/// 128-bit bitmaps indexed by byte value, so bytes above 0x7F (non-ASCII /
/// multibyte UTF-8 sequences) will never match any mask and will be rejected
/// as unexpected characters. Callers MUST NOT pass non-ASCII input.
library LibParse {
    using LibPointer for Pointer;
    using LibParseStackName for ParseState;
    using LibParseState for ParseState;
    using LibParseInterstitial for ParseState;
    using LibParseError for ParseState;
    using LibParseMeta for ParseState;
    using LibParsePragma for ParseState;
    using LibParse for ParseState;
    using LibParseOperand for ParseState;
    using LibSubParse for ParseState;
    using LibBytes for bytes;
    using LibBytes32Array for bytes32[];

    /// @notice Parses a word that matches a tail mask between cursor and end. The caller
    /// has several responsibilities while safely using this word.
    /// - The caller MUST ensure that the word is not zero length.
    ///   I.e. `end - cursor > 0`.
    /// - The caller MUST ensure the head of the word (the first character) is
    ///   valid according to some head mask. Generally it is expected that the
    ///   valid chars for a head and tail may be different.
    /// This function will extract every other character from the word, starting
    /// with the second character, and check that it is valid according to the
    /// tail mask. If any invalid characters are found, the parsing will stop
    /// looping as it is assumed the remaining data is valid as something else,
    /// just not a word.
    /// @param cursor The current cursor position pointing at the word start.
    /// @param end The end of the data to parse.
    /// @param mask The character mask for valid tail characters.
    /// @return The new cursor position after the word.
    /// @return The parsed word as a bytes32.
    function parseWord(uint256 cursor, uint256 end, uint256 mask) internal pure returns (uint256, bytes32) {
        unchecked {
            bytes32 word;
            uint256 i = 1;
            uint256 iEnd;
            {
                uint256 remaining = end - cursor;
                iEnd = remaining > 0x20 ? 0x20 : remaining;
            }
            assembly ("memory-safe") {
                // word is head + tail
                word := mload(cursor)
                // loop over the tail
                //slither-disable-next-line incorrect-shift
                for {} and(lt(i, iEnd), iszero(and(shl(byte(i, word), 1), not(mask)))) { i := add(i, 1) } {}

                // zero out the rightmost part of the mload that is not the word.
                let scrub := mul(sub(0x20, i), 8)
                word := shl(scrub, shr(scrub, word))
                cursor := add(cursor, i)
            }
            if (i == 0x20) {
                revert WordSize(string(abi.encodePacked(word)));
            }
            return (cursor, word);
        }
    }

    /// @notice Parses the left-hand side (LHS) of a source line. Handles named and
    /// anonymous stack items, whitespace, and the LHS/RHS delimiter. Reverts
    /// on unexpected characters, comments, or duplicate named stack items.
    /// @param state The parser state.
    /// @param cursor The current cursor position.
    /// @param end The end of the data to parse.
    /// @return The new cursor position after the LHS.
    //forge-lint: disable-next-line(mixed-case-function)
    function parseLHS(ParseState memory state, uint256 cursor, uint256 end) internal pure returns (uint256) {
        unchecked {
            while (cursor < end) {
                bytes32 word;
                uint256 char;
                assembly ("memory-safe") {
                    //slither-disable-next-line incorrect-shift
                    char := shl(byte(0, mload(cursor)), 1)
                }

                if (char & CMASK_LHS_STACK_HEAD > 0) {
                    // if yang we can't start new stack item
                    if (state.fsm & FSM_YANG_MASK > 0) {
                        revert UnexpectedLHSChar(state.parseErrorOffset(cursor));
                    }

                    // Named stack item.
                    if (char & CMASK_IDENTIFIER_HEAD > 0) {
                        (cursor, word) = parseWord(cursor, end, CMASK_LHS_STACK_TAIL);
                        // slither-disable-next-line unused-return
                        (bool exists,) = state.pushStackName(word);
                        // If the stack name already exists, then we
                        // revert as shadowing is not allowed.
                        if (exists) {
                            revert DuplicateLHSItem(state.parseErrorOffset(cursor));
                        }
                    }
                    // Anon stack item.
                    else {
                        cursor = LibParseChar.skipMask(cursor + 1, end, CMASK_LHS_STACK_TAIL);
                    }
                    // Bump the index regardless of whether the stack
                    // item is named or not. Both counters are packed into
                    // the low byte of their respective uint256 fields.
                    // Exceeding 0xFF would carry into the adjacent byte,
                    // silently corrupting parser state.
                    // The low byte of each field is only ever mutated by
                    // single increments (here) and resets to 0 (newSource
                    // / endLine), so reading via `& 0xFF` reliably gives
                    // the true count at this point.
                    if ((state.topLevel1 & 0xFF) == 0xFF || (state.lineTracker & 0xFF) == 0xFF) {
                        revert LHSItemCountOverflow(state.parseErrorOffset(cursor));
                    }
                    state.topLevel1++;
                    state.lineTracker++;

                    // Set yang as we are now building a stack item.
                    state.fsm |= FSM_YANG_MASK | FSM_ACTIVE_SOURCE_MASK;
                } else if (char & CMASK_WHITESPACE != 0) {
                    cursor = LibParseChar.skipMask(cursor + 1, end, CMASK_WHITESPACE);
                    // Set ying as we now open to possibilities.
                    state.fsm &= ~FSM_YANG_MASK;
                } else if (char & CMASK_LHS_RHS_DELIMITER != 0) {
                    // Set RHS and yin.
                    state.fsm = (state.fsm | FSM_ACTIVE_SOURCE_MASK) & ~FSM_YANG_MASK;
                    cursor++;
                    break;
                } else {
                    if (char & CMASK_COMMENT_HEAD != 0) {
                        revert UnexpectedComment(state.parseErrorOffset(cursor));
                    } else {
                        revert UnexpectedLHSChar(state.parseErrorOffset(cursor));
                    }
                }
            }
            return cursor;
        }
    }

    /// @notice Parses the right-hand side (RHS) of a source line. Resolves words
    /// against known opcodes, LHS stack names, and sub parsers. Handles
    /// parenthesised operand groups, literals, and line/source terminators.
    /// @param state The parser state.
    /// @param cursor The current cursor position.
    /// @param end The end of the data to parse.
    /// @return The new cursor position after the RHS.
    //forge-lint: disable-next-line(mixed-case-function)
    //slither-disable-next-line cyclomatic-complexity
    function parseRHS(ParseState memory state, uint256 cursor, uint256 end) internal view returns (uint256) {
        unchecked {
            while (cursor < end) {
                bytes32 word;
                uint256 char;
                assembly ("memory-safe") {
                    //slither-disable-next-line incorrect-shift
                    char := shl(byte(0, mload(cursor)), 1)
                }

                if (char & CMASK_RHS_WORD_HEAD > 0) {
                    // If yang we can't start a new word.
                    if (state.fsm & FSM_YANG_MASK > 0) {
                        revert UnexpectedRHSChar(state.parseErrorOffset(cursor));
                    }

                    // If the word is unknown we need the cursor at the start
                    // so that we can copy it into the subparser bytecode.
                    uint256 cursorForUnknownWord = cursor;
                    (cursor, word) = parseWord(cursor, end, CMASK_RHS_WORD_TAIL);

                    // First check if this word is in meta.
                    (bool exists, uint256 opcodeIndex) = LibParseMeta.lookupWord(state.meta, word);
                    if (exists) {
                        cursor = state.parseOperand(cursor, end);
                        OperandV2 operand = state.handleOperand(opcodeIndex);
                        state.pushOpToSource(opcodeIndex, operand);
                        // This is a real word so we expect to see parens
                        // after it.
                        state.fsm |= FSM_WORD_END_MASK;
                    }
                    // Fallback to LHS items.
                    else {
                        (exists, opcodeIndex) = state.stackNameIndex(word);
                        if (exists) {
                            state.pushOpToSource(OPCODE_STACK, OperandV2.wrap(bytes32(opcodeIndex)));
                            // Need to process highwater here because we
                            // don't have any parens to open or close.
                            state.highwater();
                        }
                        // Fallback to sub parsing.
                        else {
                            OperandV2 operand;
                            bytes memory subParserBytecode;

                            {
                                // Need to capture the word length up here before
                                // we move the cursor past the operand that might
                                // exist.
                                uint256 wordLength = cursor - cursorForUnknownWord;
                                uint256 subParserBytecodeLength = SUB_PARSER_BYTECODE_HEADER_SIZE + wordLength;
                                // We store the final parsed values in the sub parser
                                // bytecode so they can be handled as operand values,
                                // rather than needing to be parsed as literals.
                                // We have to move the cursor to keep the main parser
                                // moving, but the sub parser bytecode will be
                                // populated with the values in the state array.
                                cursor = state.parseOperand(cursor, end);
                                // The operand values length is only known after
                                // parsing the operand.
                                subParserBytecodeLength += state.operandValues.length * 0x20 + 0x20;

                                // Build the bytecode that we will be sending to the
                                // subparser. We can't yet build the byte header but
                                // we can allocate the memory for it and move the string
                                // tail and operand values into place.
                                uint256 subParserBytecodeBytesLengthOffset = SUB_PARSER_BYTECODE_HEADER_SIZE;
                                assembly ("memory-safe") {
                                    subParserBytecode := mload(0x40)
                                    // Move allocated memory past the bytes and their
                                    // length. This is NOT an aligned allocation.
                                    mstore(0x40, add(subParserBytecode, add(subParserBytecodeLength, 0x20)))
                                    // Need to record the length of the unparsed
                                    // bytes or the structure will be ambiguous to
                                    // the sub parser.
                                    mstore(add(subParserBytecode, subParserBytecodeBytesLengthOffset), wordLength)
                                    mstore(subParserBytecode, subParserBytecodeLength)
                                    // The operand of an unknown word is a pointer to
                                    // the bytecode that needs to be sub parsed.
                                    operand := subParserBytecode
                                }
                                // Copy the unknown word into the subparser bytecode
                                // after the header bytes.
                                LibMemCpy.unsafeCopyBytesTo(
                                    Pointer.wrap(cursorForUnknownWord),
                                    Pointer.wrap(
                                        Pointer.unwrap(subParserBytecode.dataPointer())
                                            + SUB_PARSER_BYTECODE_HEADER_SIZE
                                    ),
                                    wordLength
                                );
                            }
                            // Copy the operand values into place for sub
                            // parsing.
                            {
                                uint256 wordsToCopy = state.operandValues.length + 1;
                                LibMemCpy.unsafeCopyWordsTo(
                                    state.operandValues.startPointer(),
                                    subParserBytecode.endDataPointer().unsafeSubWords(wordsToCopy),
                                    wordsToCopy
                                );
                            }

                            state.pushOpToSource(OPCODE_UNKNOWN, operand);
                            // We only support words with parens for unknown words
                            // that are sent off to the sub parsers.
                            state.fsm |= FSM_WORD_END_MASK;
                        }
                    }

                    state.fsm |= FSM_YANG_MASK;
                }
                // If this is the end of a word we MUST start a paren.
                else if (state.fsm & FSM_WORD_END_MASK > 0) {
                    if (char & CMASK_LEFT_PAREN == 0) {
                        revert ExpectedLeftParen(state.parseErrorOffset(cursor));
                    }
                    // Increase the paren depth by 1.
                    // i.e. move the byte offset by 3
                    // There MAY be garbage at this new offset due to
                    // a previous paren group being deallocated. The
                    // deallocation process writes the input counter
                    // to zero but leaves a garbage word in place, with
                    // the expectation that it will be overwritten by
                    // the next paren group.
                    uint256 newParenOffset;
                    uint256 parenTracker0Offset = PARSE_STATE_PAREN_TRACKER0_OFFSET;
                    assembly ("memory-safe") {
                        newParenOffset := add(byte(0, mload(add(state, parenTracker0Offset))), 3)
                        mstore8(add(state, parenTracker0Offset), newParenOffset)
                    }
                    if (newParenOffset > MAX_PAREN_OFFSET) {
                        revert ParenOverflow();
                    }
                    cursor++;

                    // We've moved past the paren, so we are no longer at
                    // the end of a word and are yin.
                    state.fsm &= ~(FSM_WORD_END_MASK | FSM_YANG_MASK);
                } else if (char & CMASK_RIGHT_PAREN > 0) {
                    uint256 parenOffset;
                    uint256 parenTracker0Offset = PARSE_STATE_PAREN_TRACKER0_OFFSET;
                    assembly ("memory-safe") {
                        parenOffset := byte(0, mload(add(state, parenTracker0Offset)))
                    }
                    if (parenOffset == 0) {
                        revert UnexpectedRightParen(state.parseErrorOffset(cursor));
                    }
                    // Decrease the paren depth by 1.
                    // i.e. move the byte offset by -3.
                    // This effectively deallocates the paren group, so
                    // write the input counter out to the operand pointed
                    // to by the pointer we deallocated.
                    assembly ("memory-safe") {
                        let stateOffset := add(state, parenTracker0Offset)
                        parenOffset := sub(parenOffset, 3)
                        mstore8(stateOffset, parenOffset)
                        mstore8(
                            // Add 2 for the reserved bytes to the offset
                            // then read top 16 bits from the pointer.
                            // Add 1 to sandwich the inputs byte between
                            // the opcode index byte and the operand low
                            // bytes.
                            add(1, shr(0xf0, mload(add(add(stateOffset, 2), parenOffset)))),
                            // Store the input counter, which is 2 bytes
                            // after the operand write pointer.
                            byte(0, mload(add(add(stateOffset, 4), parenOffset)))
                        )
                    }
                    state.highwater();
                    cursor++;
                } else if (char & CMASK_WHITESPACE > 0) {
                    cursor = LibParseChar.skipMask(cursor + 1, end, CMASK_WHITESPACE);
                    // Set yin as we now open to possibilities.
                    state.fsm &= ~FSM_YANG_MASK;
                }
                // Handle all literals.
                else if (char & CMASK_LITERAL_HEAD > 0) {
                    cursor = state.pushLiteral(cursor, end);
                    state.highwater();
                    // We are yang now. Need the next char to release to
                    // yin.
                    state.fsm |= FSM_YANG_MASK;
                } else if (char & CMASK_EOL > 0) {
                    state.endLine(cursor);
                    cursor++;
                    break;
                }
                // End of source.
                else if (char & CMASK_EOS > 0) {
                    state.endLine(cursor);
                    state.endSource();
                    cursor++;

                    state.fsm = FSM_DEFAULT;
                    break;
                }
                // Comments aren't allowed in the RHS but we can give a
                // nicer error message than the default.
                else if (char & CMASK_COMMENT_HEAD != 0) {
                    revert UnexpectedComment(state.parseErrorOffset(cursor));
                } else {
                    revert UnexpectedRHSChar(state.parseErrorOffset(cursor));
                }
            }
            return cursor;
        }
    }

    /// @notice Top-level entry point for parsing. Processes pragmas, then iterates
    /// over interstitial, LHS, and RHS sections to build the final bytecode
    /// and constants array. Sub-parses any unknown words after initial parsing.
    /// @param state The parser state.
    /// @return bytecode The compiled bytecode.
    /// @return The constants array.
    function parse(ParseState memory state) internal view returns (bytes memory bytecode, bytes32[] memory) {
        unchecked {
            if (state.data.length > 0) {
                uint256 cursor = Pointer.unwrap(state.data.dataPointer());
                uint256 end = Pointer.unwrap(state.data.endDataPointer());
                cursor = state.parseInterstitial(cursor, end);
                cursor = state.parsePragma(cursor, end);
                while (cursor < end) {
                    cursor = state.parseInterstitial(cursor, end);
                    cursor = state.parseLHS(cursor, end);
                    cursor = state.parseRHS(cursor, end);
                }
                if (cursor != end) {
                    revert ParserOutOfBounds();
                }
                if (state.fsm & FSM_ACTIVE_SOURCE_MASK != 0) {
                    revert MissingFinalSemi(state.parseErrorOffset(cursor));
                }
            }
            //slither-disable-next-line unused-return
            (bytes memory built, bytes32[] memory constants) = state.subParseWords(state.buildBytecode());
            LibParseState.checkParseMemoryOverflow();
            return (built, constants);
        }
    }
}
