// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @dev Workaround for https://github.com/foundry-rs/foundry/issues/6572
contract ErrParse {}

/// @notice Thrown when parsing a source string and an operand opening `<` paren
/// is found somewhere that we don't expect it or can't handle it.
error UnexpectedOperand();

/// @notice Thrown when there are more operand values in the operand than the
/// handler is expecting.
error UnexpectedOperandValue();

/// @notice Thrown when parsing an operand and some required component of the
/// operand is not found in the source string.
error ExpectedOperand();

/// @notice Thrown when the number of values encountered in a single operand parsing is
/// longer than the memory allocated to hold them.
/// @param offset The offset in the source string where the error occurred.
error OperandValuesOverflow(uint256 offset);

/// @notice Thrown when parsing an operand and the closing `>` paren is not found.
/// @param offset The offset in the source string where the error occurred.
error UnclosedOperand(uint256 offset);

/// @notice The parser tried to bound an unsupported literal that we have no type for.
/// @param offset The byte offset in the source where the error occurred.
error UnsupportedLiteralType(uint256 offset);

/// @notice Encountered a string literal that is larger than supported.
/// @param offset The byte offset in the source where the error occurred.
error StringTooLong(uint256 offset);

/// @notice Encountered a string that does not have a valid end, e.g. we found some char
/// that was not printable ASCII and had to stop.
/// @param offset The byte offset in the source where the error occurred.
error UnclosedStringLiteral(uint256 offset);

/// @notice Encountered a literal that is larger than supported.
/// @param offset The byte offset in the source where the error occurred.
error HexLiteralOverflow(uint256 offset);

/// @notice Encountered a zero length hex literal.
/// @param offset The byte offset in the source where the error occurred.
error ZeroLengthHexLiteral(uint256 offset);

/// @notice Encountered an odd sized hex literal.
/// @param offset The byte offset in the source where the error occurred.
error OddLengthHexLiteral(uint256 offset);

/// @notice Encountered a hex literal with an invalid character.
/// @param offset The byte offset in the source where the error occurred.
error MalformedHexLiteral(uint256 offset);

/// @notice The expression does not finish with a semicolon (EOF).
/// @param offset The byte offset in the source where the error occurred.
error MissingFinalSemi(uint256 offset);

/// @notice Encountered an unexpected character on the LHS.
/// @param offset The byte offset in the source where the error occurred.
error UnexpectedLHSChar(uint256 offset);

/// @notice Encountered an unexpected character on the RHS.
/// @param offset The byte offset in the source where the error occurred.
error UnexpectedRHSChar(uint256 offset);

/// @notice More specific version of UnexpectedRHSChar where we specifically expected
/// a left paren but got some other char.
/// @param offset The byte offset in the source where the error occurred.
error ExpectedLeftParen(uint256 offset);

/// @notice Encountered a right paren without a matching left paren.
/// @param offset The byte offset in the source where the error occurred.
error UnexpectedRightParen(uint256 offset);

/// @notice Encountered an unclosed left paren.
/// @param offset The byte offset in the source where the error occurred.
error UnclosedLeftParen(uint256 offset);

/// @notice Encountered a comment outside the interstitial space between lines.
/// @param offset The byte offset in the source where the error occurred.
error UnexpectedComment(uint256 offset);

/// @notice Encountered a comment that never ends.
/// @param offset The byte offset in the source where the error occurred.
error UnclosedComment(uint256 offset);

/// @notice Encountered a comment start sequence that is malformed.
/// @param offset The byte offset in the source where the error occurred.
error MalformedCommentStart(uint256 offset);

/// @notice Thrown when a stack name is duplicated. Shadowing in all forms is
/// disallowed in Rainlang.
/// @param offset The byte offset of the duplicate item in the parse data.
error DuplicateLHSItem(uint256 offset);

/// @notice Encountered too many LHS items.
/// @param offset The byte offset in the source where the error occurred.
error ExcessLHSItems(uint256 offset);

/// @notice Encountered inputs where they can't be handled.
/// @param offset The byte offset in the source where the error occurred.
error NotAcceptingInputs(uint256 offset);

/// @notice Encountered too many RHS items.
/// @param offset The byte offset in the source where the error occurred.
error ExcessRHSItems(uint256 offset);

/// @notice Encountered a word that is longer than 32 bytes.
/// @param word The word that exceeded the maximum length.
error WordSize(string word);

/// @notice Parsed a word that is not in the meta.
/// @param word The word that was not found.
error UnknownWord(string word);

/// @notice The parser exceeded the maximum number of sources that it can build.
error MaxSources();

/// @notice The parser encountered a dangling source. This is a bug in the parser.
error DanglingSource();

/// @notice The parser moved past the end of the data. Defensive guard only — all
/// sub-parsers (parseInterstitial, parseLHS, parseRHS) receive `end` and
/// respect it, so this condition is unreachable under normal operation. It
/// exists to catch internal sub-parser bugs that advance the cursor past
/// `end`. Cannot be tested without mocking a sub-parser to force overshoot.
error ParserOutOfBounds();

/// @notice The parser encountered a stack deeper than it can process in the
/// memory region allocated for stack names.
error ParseStackOverflow();

/// @notice The parser encountered a stack underflow.
error ParseStackUnderflow();

/// @notice The parser encountered a paren group deeper than it can process in
/// the memory region allocated for paren tracking.
error ParenOverflow();

/// @notice The parser did not find any whitespace after the pragma keyword.
/// @param offset The byte offset in the source where the error occurred.
error NoWhitespaceAfterUsingWordsFrom(uint256 offset);

/// @notice The parser encountered a literal that it cannot use as a sub parser.
/// @param offset The byte offset in the source where the error occurred.
error InvalidSubParser(uint256 offset);

/// @notice The parser encountered an unclosed sub parsed literal.
/// @param offset The byte offset in the source where the error occurred.
error UnclosedSubParseableLiteral(uint256 offset);

/// @notice The parser encountered a sub parseable literal with a missing dispatch.
/// @param offset The byte offset in the source where the error occurred.
error SubParseableMissingDispatch(uint256 offset);

/// @notice The sub parser returned some bytecode that the main parser could not
/// understand.
/// @param bytecode The bytecode that was returned by the sub parser.
error BadSubParserResult(bytes bytecode);

/// @notice Thrown when there are more than 16 inputs or outputs for a given opcode.
/// @param offset The byte offset in the source where the error occurred.
error OpcodeIOOverflow(uint256 offset);

/// @notice Thrown when an operand value is larger than the maximum allowed.
error OperandOverflow();

/// @notice The parser's free memory pointer exceeded 0x10000, which would corrupt
/// the 16-bit pointers used internally by the parse system.
/// @param freeMemoryPointer The free memory pointer value that exceeded the limit.
error ParseMemoryOverflow(uint256 freeMemoryPointer);

/// @notice A single top-level item exceeded 255 opcodes. The per-item byte
/// counter would silently wrap, corrupting source bytecode.
error SourceItemOpsOverflow();

/// @notice The total number of opcodes across all top-level items in a single
/// source exceeded 255. The source prefix byte can only represent 0-255.
error SourceTotalOpsOverflow();

/// @notice A paren group exceeded 255 inputs. The per-paren byte counter
/// would silently wrap, corrupting operand data.
error ParenInputOverflow();

/// @notice A single line exceeded the maximum number of RHS top-level items
/// that can be tracked in the 256-bit lineTracker (14 items).
error LineRHSItemsOverflow();

/// @notice Thrown when a numeric literal starts with `0X` (uppercase). Only
/// lowercase `0x` is a valid hexadecimal prefix. Uppercase `0X` would
/// otherwise silently parse as decimal zero.
/// @param offset The byte offset in the source where the error occurred.
error UppercaseHexPrefix(uint256 offset);

/// @notice The number of LHS items overflowed the single-byte counter in
/// `lineTracker` (per line) or `topLevel1` (per source). Maximum 255 LHS
/// items per line and per source.
/// @param offset The byte offset in the source where the error occurred.
error LHSItemCountOverflow(uint256 offset);
