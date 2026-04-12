// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OperandV2, OPCODE_CONSTANT} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibParseStackTracker, ParseStackTracker} from "./LibParseStackTracker.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {LibMemCpy} from "rain.solmem/lib/LibMemCpy.sol";
import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {
    DanglingSource,
    MaxSources,
    ParseMemoryOverflow,
    ParseStackOverflow,
    UnclosedLeftParen,
    ExcessRHSItems,
    ExcessLHSItems,
    NotAcceptingInputs,
    UnsupportedLiteralType,
    InvalidSubParser,
    OpcodeIOOverflow,
    SourceItemOpsOverflow,
    SourceTotalOpsOverflow,
    ParenInputOverflow,
    LineRHSItemsOverflow
} from "../../error/ErrParse.sol";
import {LibParseLiteral} from "./literal/LibParseLiteral.sol";
import {LibParseError} from "./LibParseError.sol";

/// @dev The sub-parser linked list packs an address (160 bits, low) and a
/// memory pointer (96 bits, high) into a single bytes32. This constant is the
/// bit shift used to pack/unpack the pointer portion. It equals the address
/// width (160 bits = 0xA0).
uint256 constant SUB_PARSER_POINTER_SHIFT = 0xA0;

/// @dev Initial state of an active source is just the starting offset which is
/// 0x20.
uint256 constant EMPTY_ACTIVE_SOURCE = 0x20;

/// @dev Bit 0 of the FSM. When set, the parser is in "yang" state (building
/// an RHS word). When clear, the parser is in "yin" state (between words).
uint256 constant FSM_YANG_MASK = 1;
/// @dev Bit 1 of the FSM. When set, the current word has ended and the parser
/// should finalize it before processing the next character.
uint256 constant FSM_WORD_END_MASK = 1 << 1;
/// @dev Bit 2 of the FSM. When set, the current line is still accepting LHS
/// input names. Cleared after the first RHS item on a line.
uint256 constant FSM_ACCEPTING_INPUTS_MASK = 1 << 2;

/// @dev If a source is active we cannot finish parsing without a semi to trigger
/// finalisation.
uint256 constant FSM_ACTIVE_SOURCE_MASK = 1 << 3;

/// @dev fsm default state is:
/// - yin
/// - not word end
/// - accepting inputs
uint256 constant FSM_DEFAULT = FSM_ACCEPTING_INPUTS_MASK;

/// @dev The operand values array is 4 words long. In the future we could have
/// some kind of logic that reallocates and expands this if we discover that
/// we need more than 4 operands for a single opcode. Currently there are no
/// opcodes in the main parser that require more than 4 operands. Of course some
/// sub parser could implement something that expects more than 4, in which case
/// we will have to revisit this, but it won't be a breaking change. Consider
/// that operands in the output are only 2 bytes, so a 4 value operand array is
/// already only allowing for 4 bits per value on average, which is pretty tight
/// for anything other than bit flags.
uint256 constant OPERAND_VALUES_LENGTH = 4;

/// @dev Byte offset of `topLevel0` within a memory `ParseState` struct.
/// Used in assembly to read/write per-source word counters.
uint256 constant PARSE_STATE_TOP_LEVEL0_OFFSET = 0x20;

/// @dev Byte offset of the data region of `topLevel0`, past the counter
/// byte. Each byte in this region is a per-word ops counter.
uint256 constant PARSE_STATE_TOP_LEVEL0_DATA_OFFSET = 0x21;

/// @dev Byte offset of `parenTracker0` within a memory `ParseState` struct.
/// Used in assembly to read/write paren depth and input counters.
uint256 constant PARSE_STATE_PAREN_TRACKER0_OFFSET = 0x60;

/// @dev Byte offset of `lineTracker` within a memory `ParseState` struct.
/// Used in assembly to snapshot source head pointers per line.
uint256 constant PARSE_STATE_LINE_TRACKER_OFFSET = 0xa0;

/// @dev Maximum RHS offset value. The RHS offset is stored as a single
/// byte within the topLevel0 field but shares the word with other packed
/// fields, so it must not exceed 62 (0x3e). The check uses >= 0x3f (63)
/// to reject offset 63 and above.
uint256 constant MAX_STACK_RHS_OFFSET = 0x3f;

/// @notice The parser is stateful. This struct keeps track of the entire state.
/// @param activeSourcePtr The pointer to the current source being built.
/// The active source being pointed to is:
/// - low 16 bits: bitwise offset into the source for the next word to be
///   written. Starts at 0x20. Once a source is no longer the active source, i.e.
///   it is full and a member of the LL tail, the offset is replaced with a
///   pointer to the next source (towards the head) to build a doubly linked
///   list.
/// - mid 16 bits: pointer to the previous active source (towards the tail). This
///   is a linked list of sources that are built RTL and then reversed to LTR to
///   eval.
/// - high bits: 4 byte opcodes and operand pairs.
/// @param sourcesBuilder A builder for the sources array. This is a 256 bit
/// integer where each 16 bits is a literal memory pointer to a source.
/// @param fsm The finite state machine representation of the parser.
/// - bit 0 (FSM_YANG_MASK): yang/yin => 0 = yin, 1 = yang
/// - bit 1 (FSM_WORD_END_MASK): word end => 0 = not end, 1 = end
/// - bit 2 (FSM_ACCEPTING_INPUTS_MASK): accepting inputs => 0 = not accepting, 1 = accepting
/// - bit 3 (FSM_ACTIVE_SOURCE_MASK): active source => 0 = no active source, 1 = active source
/// @param topLevel0 Memory region for stack word counters. The first byte is a
/// counter/offset into the region, which increments for every top level item
/// parsed on the RHS. The remaining 31 bytes are the word counters for each
/// stack item, which are incremented for every op pushed to the source. This is
/// reset to 0 for every new source.
/// @param topLevel1 31 additional bytes of stack words, allowing for 62 top
/// level stack items total per source. The final byte is used to count the
/// stack height according to the LHS for the current source. This is reset to 0
/// for every new source.
/// @param parenTracker0 Memory region for tracking pointers to words in the
/// source, and counters for the number of words in each paren group. The first
/// byte is a counter/offset into the region. The second byte is a phantom
/// counter for the root level, the remaining 30 bytes are the paren group words.
/// @param parenTracker1 32 additional bytes of paren group words.
/// @param lineTracker A 32 byte memory region for tracking the current line.
/// Will be partially reset for each line when `endLine` is called. Fully
/// reset when a new source is started.
/// Bytes from low to high:
/// - byte 0: Lowest byte is the number of LHS items parsed. This is the low
/// byte so that a simple ++ is a valid operation on the line tracker while
/// parsing the LHS. This is reset to 0 for each new line.
/// - byte 1: A snapshot of the first high byte of `topLevel0`, i.e. the offset
/// of top level items as at the beginning of the line. This is reset to the high
/// byte of `topLevel0` on each new line.
/// - bytes 2+: A sequence of 2 byte pointers to before the start of each top
/// level item, which is implicitly after the end of the previous top level item.
/// Allows us to quickly find the start of the RHS source for each top level
/// item.
/// @param subParsers Linked list of sub-parser addresses registered via
/// `using-words-from` pragmas. Each entry is a `bytes32` with the address in
/// the low 160 bits and a pointer to the next entry in the high bits.
/// @param stackNames A linked list of stack names. As the parser encounters
/// named stack items it pushes them onto this linked list. The linked list is
/// in FILO order, so the first item on the stack is the last item in the list.
/// This makes it more efficient to reference more recent stack names on the RHS.
/// @param stackNameBloom Bloom filter over stack name fingerprints. Used for
/// fast negative lookups before traversing the `stackNames` linked list.
/// @param constantsBuilder A builder for the constants array.
/// - low 16 bits: the height (length) of the constants array.
/// - high 240 bits: a linked list of constant values. Each constant value is
///   stored as a 256 bit key/value pair. The key is the fingerprint of the
///   constant value, and the value is the constant value itself.
/// @param constantsBloom Bloom filter over constant value fingerprints. Used
/// to quickly dedupe constants before traversing the `constantsBuilder` list.
/// @param literalParsers A 256 bit integer where each 16 bits is a function
/// pointer to a literal parser.
/// @param operandHandlers Packed 2-byte function pointers to operand handler
/// functions, one per opcode. Indexed by opcode to parse operand bytes.
/// @param operandValues Scratch array for operand values being parsed for the
/// current word. Fixed length of `OPERAND_VALUES_LENGTH` (4).
/// @param stackTracker Tracks stack height, high watermark, and input count
/// for the current source. Used by `endLine` to emit per-word IO metadata.
/// @param data Raw input bytes being parsed. Sub-parsers also receive this
/// to resolve words and literals not recognized by the main parser.
/// @param meta Packed parse metadata (bloom filter + fingerprint table) used
/// by `lookupWord` to resolve word strings to opcode indices.
struct ParseState {
    /// @dev START things that are referenced directly in assembly by hardcoded
    /// offsets. E.g.
    /// - `pushOpToSource`
    /// - `snapshotSourceHeadToLineTracker`
    /// - `newSource`
    uint256 activeSourcePtr;
    uint256 topLevel0;
    uint256 topLevel1;
    uint256 parenTracker0;
    uint256 parenTracker1;
    uint256 lineTracker;
    /// - `pushSubParser`
    bytes32 subParsers;
    /// @dev END things that are referenced directly in assembly by hardcoded
    /// offsets.
    uint256 sourcesBuilder;
    uint256 fsm;
    uint256 stackNames;
    uint256 stackNameBloom;
    uint256 constantsBuilder;
    bytes32 constantsBloom;
    bytes literalParsers;
    bytes operandHandlers;
    bytes32[] operandValues;
    ParseStackTracker stackTracker;
    bytes data;
    bytes meta;
}

/// @title LibParseState
/// @notice Utilities for constructing and managing `ParseState` during parsing.
library LibParseState {
    using LibParseState for ParseState;
    using LibParseStackTracker for ParseStackTracker;
    using LibParseError for ParseState;
    using LibParseLiteral for ParseState;
    using LibUint256Array for uint256[];

    /// @notice Allocates a new 32-byte-aligned active source pointer in memory and
    /// links it into the doubly linked list of source slots.
    ///
    /// The free-pointer arithmetic is unchecked. This is safe only because
    /// `checkParseMemoryOverflow` keeps the free memory pointer below
    /// `0x10000`, so the alignment and bump additions cannot overflow.
    /// @param oldActiveSourcePointer The pointer to the previous active source
    /// slot to link into the doubly linked list.
    /// @return The pointer to the newly allocated active source slot.
    function newActiveSourcePointer(uint256 oldActiveSourcePointer) internal pure returns (uint256) {
        uint256 activeSourcePtr;
        uint256 emptyActiveSource = EMPTY_ACTIVE_SOURCE;
        assembly ("memory-safe") {
            // The active source pointer MUST be aligned to 32 bytes because we
            // rely on alignment to know when we have filled a source and need
            // to create a new one, or need to jump through the linked list.
            activeSourcePtr := and(add(mload(0x40), 0x1F), not(0x1F))
            mstore(activeSourcePtr, or(emptyActiveSource, shl(0x10, oldActiveSourcePointer)))
            mstore(0x40, add(activeSourcePtr, 0x20))

            // The old tail head must now point back to the new tail head.
            mstore(oldActiveSourcePointer, or(and(mload(oldActiveSourcePointer), not(0xFFFF)), activeSourcePtr))
        }
        return activeSourcePtr;
    }

    /// @notice Resets all per-source state fields to prepare for parsing a new source.
    /// Allocates a fresh active source pointer and zeroes out top-level
    /// counters, paren trackers, line tracker, stack names, and stack tracker.
    /// @param state The parse state to reset.
    function resetSource(ParseState memory state) internal pure {
        state.activeSourcePtr = newActiveSourcePointer(0);
        state.topLevel0 = 0;
        state.topLevel1 = 0;
        state.parenTracker0 = 0;
        state.parenTracker1 = 0;
        state.lineTracker = 0;

        // We don't reset sub parsers because they are global and immutable to
        // the parsing process.

        state.stackNames = 0;
        state.stackNameBloom = 0;
        state.stackTracker = ParseStackTracker.wrap(0);
    }

    /// @notice Constructs and returns a fully initialised `ParseState` from the given
    /// raw expression data, word metadata, operand handlers, and literal
    /// parsers. Calls `resetSource` to set up the first active source.
    /// @param data The raw expression data to parse.
    /// @param meta The word metadata for opcode lookups.
    /// @param operandHandlers Packed 2-byte function pointers for operand
    /// handlers.
    /// @param literalParsers Packed 2-byte function pointers for literal
    /// parsers.
    /// @return The fully initialised parse state.
    function newState(bytes memory data, bytes memory meta, bytes memory operandHandlers, bytes memory literalParsers)
        internal
        pure
        returns (ParseState memory)
    {
        ParseState memory state = ParseState(
            // activeSource
            // (will be built in `resetSource`)
            0,
            // topLevel0
            0,
            // topLevel1
            0,
            // parenTracker0
            0,
            // parenTracker1
            0,
            // lineTracker
            // (will be built in `resetSource`)
            0,
            // sub parsers
            0,
            // sourcesBuilder
            0,
            // fsm
            FSM_DEFAULT,
            // stackNames
            0,
            // stackNameBloom
            0,
            // constantsBuilder
            0,
            // constantsBloom
            0,
            // literalParsers
            literalParsers,
            // operandHandlers
            operandHandlers,
            // operandValues
            new bytes32[](OPERAND_VALUES_LENGTH),
            // stackTracker
            ParseStackTracker.wrap(0),
            // data bytes
            data,
            // meta bytes
            meta
        );
        state.resetSource();
        return state;
    }

    /// @notice Pushes a `uint256` representation of a sub parser onto the linked list of
    /// sub parsers in memory. The sub parser is expected to be an `address` so
    /// the pointer for the linked list is ORed in the high 96 bits of the
    /// `uint256` (above the 160-bit address). This provides ample space for
    /// any practical memory pointer.
    /// @param state The parse state containing the sub parser linked list.
    /// @param cursor The current cursor for error reporting.
    /// @param subParser The sub parser address as a bytes32.
    function pushSubParser(ParseState memory state, uint256 cursor, bytes32 subParser) internal pure {
        if (uint256(subParser) > uint256(type(uint160).max)) {
            revert InvalidSubParser(state.parseErrorOffset(cursor));
        }

        bytes32 tail = state.subParsers;
        // Move the tail off to a new allocation.
        uint256 tailPointer;
        assembly ("memory-safe") {
            tailPointer := mload(0x40)
            mstore(0x40, add(tailPointer, 0x20))
            mstore(tailPointer, tail)
        }
        // Put the tail pointer in the high bits of the new head.
        state.subParsers = subParser | bytes32(tailPointer << SUB_PARSER_POINTER_SHIFT);
    }

    /// @notice Builds a memory array of sub parsers from the linked list of sub parsers.
    /// @param state The parse state containing the sub parser linked list.
    /// @return The array of sub parser addresses.
    function exportSubParsers(ParseState memory state) internal pure returns (address[] memory) {
        bytes32 tail = state.subParsers;
        uint256[] memory subParsersUint256;
        uint256 addressMask = type(uint160).max;
        assembly ("memory-safe") {
            subParsersUint256 := mload(0x40)
            let cursor := add(subParsersUint256, 0x20)
            let len := 0
            for {} gt(tail, 0) {} {
                mstore(cursor, and(tail, addressMask))
                cursor := add(cursor, 0x20)
                tail := mload(shr(SUB_PARSER_POINTER_SHIFT, tail))
                len := add(len, 1)
            }
            mstore(subParsersUint256, len)
            mstore(0x40, cursor)
        }
        subParsersUint256.reverse();
        address[] memory subParsers;
        assembly ("memory-safe") {
            subParsers := subParsersUint256
        }
        return subParsers;
    }

    /// @notice Snapshots the current source head pointer into the line tracker at the
    /// appropriate offset, but only when the current top-level word counter is
    /// zero. This records where each top-level RHS item begins in the source.
    /// @param state The parse state to snapshot.
    function snapshotSourceHeadToLineTracker(ParseState memory state) internal pure {
        uint256 activeSourcePtr = state.activeSourcePtr;
        uint256 topLevel0Offset = PARSE_STATE_TOP_LEVEL0_OFFSET;
        uint256 lineTrackerOffset = PARSE_STATE_LINE_TRACKER_OFFSET;
        bool didOverflow;
        assembly ("memory-safe") {
            let topLevel0Pointer := add(state, topLevel0Offset)
            let totalRHSTopLevel := byte(0, mload(topLevel0Pointer))
            // Only do stuff if the current word counter is zero.
            if iszero(byte(0, mload(add(topLevel0Pointer, add(totalRHSTopLevel, 1))))) {
                let byteOffset := div(and(mload(activeSourcePtr), 0xFFFF), 8)
                let sourceHead := add(activeSourcePtr, sub(0x20, byteOffset))

                let lineTracker := mload(add(state, lineTrackerOffset))
                let lineRHSTopLevel := sub(totalRHSTopLevel, byte(30, lineTracker))
                let offset := mul(0x10, add(lineRHSTopLevel, 1))
                // 14 items max — offset 0xF0 is the last valid slot.
                // Beyond that, shl shifts past 256 bits and silently
                // discards the pointer.
                didOverflow := gt(offset, 0xF0)
                lineTracker := or(lineTracker, shl(offset, sourceHead))
                mstore(add(state, lineTrackerOffset), lineTracker)
            }
        }
        if (didOverflow) {
            revert LineRHSItemsOverflow();
        }
    }

    /// @notice Finalises the current line by validating paren balance, reconciling
    /// LHS and RHS item counts, computing opcode input/output counts, and
    /// updating the stack tracker. Resets the line tracker for the next line.
    /// @param state The parse state to finalise the current line for.
    /// @param cursor The current cursor position for error reporting.
    //slither-disable-next-line cyclomatic-complexity
    function endLine(ParseState memory state, uint256 cursor) internal pure {
        unchecked {
            {
                uint256 parenOffset;
                uint256 parenTracker0Offset = PARSE_STATE_PAREN_TRACKER0_OFFSET;
                assembly ("memory-safe") {
                    parenOffset := byte(0, mload(add(state, parenTracker0Offset)))
                }
                if (parenOffset > 0) {
                    revert UnclosedLeftParen(state.parseErrorOffset(cursor));
                }
            }

            // This will snapshot the current head of the source, which will be
            // the start of where we want to read for the final line RHS item,
            // if it exists.
            state.snapshotSourceHeadToLineTracker();

            // Preserve the accepting inputs flag but set
            // everything else back to defaults. Also set that
            // there is an active source.
            state.fsm = (FSM_DEFAULT & ~FSM_ACCEPTING_INPUTS_MASK) | (state.fsm & FSM_ACCEPTING_INPUTS_MASK)
                | FSM_ACTIVE_SOURCE_MASK;

            //forge-lint: disable-next-line(mixed-case-variable)
            uint256 lineLHSItems = state.lineTracker & 0xFF;
            // Total number of RHS at top level is the top byte of topLevel0.
            //forge-lint: disable-next-line(mixed-case-variable)
            uint256 totalRHSTopLevel = state.topLevel0 >> 0xf8;
            // Snapshot for RHS from start of line is second low byte of
            // lineTracker.
            //forge-lint: disable-next-line(mixed-case-variable)
            uint256 lineRHSTopLevel = totalRHSTopLevel - ((state.lineTracker >> 8) & 0xFF);

            // If:
            // - we are accepting inputs
            // - the RHS on this line is empty
            // Then we treat the LHS items as inputs to the source. This means that
            // we need to move the RHS offset to the end of the LHS items. There MAY
            // be 0 LHS items, e.g. if the entire source is empty. This can only
            // happen at the start of the source, as any RHS item immediately flips
            // the FSM to not accepting inputs.
            if (lineRHSTopLevel == 0) {
                if (state.fsm & FSM_ACCEPTING_INPUTS_MASK == 0) {
                    revert NotAcceptingInputs(state.parseErrorOffset(cursor));
                } else {
                    // As there are no RHS opcodes yet we can simply set topLevel0 directly.
                    // This is the only case where we defer to the LHS to tell
                    // us how many top level items there are.
                    totalRHSTopLevel += lineLHSItems;
                    state.topLevel0 = totalRHSTopLevel << 0xf8;

                    // Push the inputs onto the stack tracker.
                    state.stackTracker = state.stackTracker.pushInputs(lineLHSItems);
                }
            }
            // If:
            // - there are multiple RHS items on this line
            // Then there must be the same number of LHS items. Multi or zero output
            // RHS top level items are NOT supported unless they are the only RHS
            // item on that line.
            else if (lineRHSTopLevel > 1) {
                if (lineLHSItems < lineRHSTopLevel) {
                    revert ExcessRHSItems(state.parseErrorOffset(cursor));
                } else if (lineLHSItems > lineRHSTopLevel) {
                    revert ExcessLHSItems(state.parseErrorOffset(cursor));
                }
            }

            // Follow pointers to the start of the RHS item.
            uint256 topLevelOffset = 1 + totalRHSTopLevel - lineRHSTopLevel;
            uint256 end = (0x10 * lineRHSTopLevel) + 0x20;
            for (uint256 offset = 0x20; offset < end; offset += 0x10) {
                uint256 itemSourceHead = (state.lineTracker >> offset) & 0xFFFF;
                uint256 opsDepth;
                uint256 topLevel0Offset = PARSE_STATE_TOP_LEVEL0_OFFSET;
                assembly ("memory-safe") {
                    opsDepth := byte(0, mload(add(state, add(topLevel0Offset, topLevelOffset))))
                }
                for (uint256 i = 1; i <= opsDepth; i++) {
                    {
                        // We've hit the end of a LL item so have to jump towards the
                        // tail to keep going. This makes the assumption that
                        // the relevant pointers are aligned to 32 bytes, which
                        // is handled on allocation in `newActiveSourcePointer`.
                        if (itemSourceHead % 0x20 == 0x1c) {
                            assembly ("memory-safe") {
                                itemSourceHead := shr(0xf0, mload(itemSourceHead))
                            }
                        }
                        uint256 opInputs;
                        assembly ("memory-safe") {
                            opInputs := byte(1, mload(itemSourceHead))
                        }
                        state.stackTracker = state.stackTracker.pop(opInputs);
                        // Nested multi or zero output RHS items are NOT
                        // supported. If the top level RHS item is the ONLY RHS
                        // item on the line then it MAY have multiple or zero
                        // outputs. In this case we defer to the LHS to tell us
                        // how many outputs there are. If the LHS is wrong then
                        // later integrity checks will need to flag it.
                        uint256 opOutputs = i == opsDepth && lineRHSTopLevel == 1 ? lineLHSItems : 1;
                        state.stackTracker = state.stackTracker.push(opOutputs);

                        // Merge the op outputs and inputs into a single byte.
                        if (opOutputs > 0x0F || opInputs > 0x0F) {
                            revert OpcodeIOOverflow(state.parseErrorOffset(cursor));
                        }
                        assembly ("memory-safe") {
                            mstore8(add(itemSourceHead, 1), or(shl(4, opOutputs), opInputs))
                        }
                    }
                    itemSourceHead += 4;
                }
                topLevelOffset++;
            }

            state.lineTracker = totalRHSTopLevel << 8;
        }
    }

    /// @notice We potentially just closed out some group of arbitrarily nested parens
    /// OR a lone literal value at the top level. IF we are at the top level we
    /// move the immutable stack highwater mark forward 1 item, which moves the
    /// RHS offset forward 1 byte to start a new word counter.
    /// @param state The parse state to advance the highwater mark for.
    function highwater(ParseState memory state) internal pure {
        uint256 parenOffset;
        uint256 parenTracker0Offset = PARSE_STATE_PAREN_TRACKER0_OFFSET;
        assembly ("memory-safe") {
            parenOffset := byte(0, mload(add(state, parenTracker0Offset)))
        }
        if (parenOffset == 0) {
            //forge-lint: disable-next-line(mixed-case-variable)
            uint256 newStackRHSOffset;
            uint256 topLevel0Offset = PARSE_STATE_TOP_LEVEL0_OFFSET;
            assembly ("memory-safe") {
                let stackRHSOffsetPtr := add(state, topLevel0Offset)
                newStackRHSOffset := add(byte(0, mload(stackRHSOffsetPtr)), 1)
                mstore8(stackRHSOffsetPtr, newStackRHSOffset)
            }
            if (newStackRHSOffset >= MAX_STACK_RHS_OFFSET) {
                revert ParseStackOverflow();
            }
        }
    }

    /// @notice Computes a single-bit bloom filter hash for a constant value, used to
    /// quickly check for potential duplicates before traversing the linked list.
    /// @param value The constant value to compute the bloom hash for.
    /// @return bloom The single-bit bloom filter hash.
    function constantValueBloom(bytes32 value) internal pure returns (bytes32 bloom) {
        return bytes32(uint256(1) << (uint256(value) % 256));
    }

    /// @notice Includes a constant value in the constants linked list so that it will
    /// appear in the final constants array.
    /// @param state The parse state containing the constants builder.
    /// @param value The constant value to push onto the linked list.
    function pushConstantValue(ParseState memory state, bytes32 value) internal pure {
        unchecked {
            uint256 headPtr;
            uint256 tailPtr = state.constantsBuilder >> 0x10;
            assembly ("memory-safe") {
                // Allocate two words.
                headPtr := mload(0x40)
                mstore(0x40, add(headPtr, 0x40))

                // First word is the pointer to the tail of the LL.
                mstore(headPtr, tailPtr)
                // Second word is the value.
                mstore(add(headPtr, 0x20), value)
            }

            // Inc the constants height by 1 and set the new head pointer.
            state.constantsBuilder = ((state.constantsBuilder & 0xFFFF) + 1) | (headPtr << 0x10);

            // Merge in the value bloom.
            state.constantsBloom |= constantValueBloom(value);
        }
    }

    /// @notice Parses a literal value at the cursor, deduplicates it against existing
    /// constants using a bloom filter and linked list, and pushes a constant
    /// opcode referencing the value's index onto the current source.
    /// @param state The parse state.
    /// @param cursor The current cursor position pointing at the literal.
    /// @param end The end of the source data.
    /// @return The updated cursor position after parsing the literal.
    function pushLiteral(ParseState memory state, uint256 cursor, uint256 end) internal view returns (uint256) {
        unchecked {
            bytes32 constantValue;
            bool success;
            (success, cursor, constantValue) = state.tryParseLiteral(cursor, end);
            // Don't continue trying to push something that we can't parse.
            if (!success) {
                revert UnsupportedLiteralType(state.parseErrorOffset(cursor));
            }

            // Whether the constant is a duplicate.
            bool exists = false;

            // The index of the constant in the constants builder LL. This is
            // starting from the top of the linked list, so the final index is
            // the height of the linked list minus this value.
            uint256 t = 0;

            // If the constant is in the bloom filter, then it MAY be a
            // duplicate. Try to find the constant value in the linked list of
            // constants.
            //
            // If the constant is NOT in the bloom filter, then it is definitely
            // NOT a duplicate, so avoid traversing the linked list.
            //
            // Worst case is a false positive in the bloom filter, which means
            // we traverse the linked list and find no match. This is O(1) for
            // the bloom filter and O(n) for the linked list traversal.
            if (state.constantsBloom & constantValueBloom(constantValue) != 0) {
                uint256 tailPtr = state.constantsBuilder >> 0x10;
                while (tailPtr != 0 && !exists) {
                    ++t;
                    bytes32 tailValue;
                    assembly ("memory-safe") {
                        tailValue := mload(add(tailPtr, 0x20))
                        tailPtr := mload(tailPtr)
                    }
                    exists = constantValue == tailValue;
                }
            }

            // Push the constant opcode to the source.
            // The index is either the height of the constants, if the constant
            // is NOT a duplicate, or the height minus the index of the
            // duplicate. This is because the final constants array is built
            // 0 indexed from the bottom of the linked list to the top.
            {
                uint256 constantsHeight = state.constantsBuilder & 0xFFFF;
                state.pushOpToSource(
                    OPCODE_CONSTANT, OperandV2.wrap(bytes32(exists ? constantsHeight - t : constantsHeight))
                );
            }

            // If the literal is not a duplicate, then we need to add it to the
            // linked list of literals so that `t` can point to it, and we can
            // build the constants array from the values in the linked list
            // later.
            if (!exists) {
                state.pushConstantValue(constantValue);
            }

            return cursor;
        }
    }

    /// @notice Writes an opcode and operand pair into the active source at the current
    /// bit offset. Updates paren tracking counters, top-level word counters,
    /// and allocates a new source slot if the current one is full.
    /// The caller MUST ensure `opcode` fits in 8 bits and `operand` fits in
    /// 16 bits. Wider values will silently corrupt adjacent slots in the
    /// packed source because neither is masked before shifting into position.
    /// @param state The parse state containing the active source.
    /// @param opcode The opcode to write into the source. MUST fit in 8 bits.
    /// @param operand The operand to write alongside the opcode. MUST fit in
    /// 16 bits.
    function pushOpToSource(ParseState memory state, uint256 opcode, OperandV2 operand) internal pure {
        unchecked {
            // This might be a top level item so try to snapshot its pointer to
            // the line tracker before writing the stack counter.
            state.snapshotSourceHeadToLineTracker();

            // As soon as we push an op to source we can no longer accept inputs.
            state.fsm &= ~FSM_ACCEPTING_INPUTS_MASK;
            // We also have an active source;
            state.fsm |= FSM_ACTIVE_SOURCE_MASK;

            // Increment the top level stack counter for the current top level
            // word. MAY be setting 0 to 1 if this is the top level.
            {
                bool didOverflow;
                uint256 topLevel0Offset = PARSE_STATE_TOP_LEVEL0_OFFSET;
                assembly ("memory-safe") {
                    let counterOffset := add(state, topLevel0Offset)
                    let counterPointer := add(counterOffset, add(byte(0, mload(counterOffset)), 1))
                    let val := byte(0, mload(counterPointer))
                    didOverflow := eq(val, 0xFF)
                    // Increment the counter.
                    mstore8(counterPointer, add(val, 1))
                }
                if (didOverflow) {
                    revert SourceItemOpsOverflow();
                }
            }

            bytes32 activeSource;
            uint256 offset;
            uint256 activeSourcePointer = state.activeSourcePtr;
            {
                bool didOverflow;
                uint256 parenTracker0Offset = PARSE_STATE_PAREN_TRACKER0_OFFSET;
                assembly ("memory-safe") {
                    activeSource := mload(activeSourcePointer)
                    // The low 16 bits of the active source is the current offset.
                    offset := and(activeSource, 0xFFFF)

                    // The offset is in bits so for a byte pointer we need to divide
                    // by 8, then add 4 to move to the operand low byte.
                    let inputsBytePointer := sub(add(activeSourcePointer, 0x20), add(div(offset, 8), 4))

                    // Increment the paren input counter. The input counter is for the paren
                    // group that is currently being built. This means the counter is for
                    // the paren group that is one level above the current paren offset.
                    // Assumes that every word has exactly 1 output, therefore the input
                    // counter always increases by 1.
                    let inputCounterPos := add(state, parenTracker0Offset)
                    inputCounterPos := add(
                        add(
                            inputCounterPos,
                            // the offset
                            byte(0, mload(inputCounterPos))
                        ),
                        // +2 for the reserved bytes -1 to move back to the counter
                        // for the previous paren group.
                        1
                    )
                    // Increment the parent counter.
                    let val := byte(0, mload(inputCounterPos))
                    didOverflow := eq(val, 0xFF)
                    mstore8(inputCounterPos, add(val, 1))
                    // Zero out the current counter.
                    mstore8(add(inputCounterPos, 3), 0)

                    // Write the operand low byte pointer into the paren tracker.
                    // Move 3 bytes after the input counter pos, then shift down 32
                    // bytes to accommodate the full mload.
                    let parenTrackerPointer := sub(inputCounterPos, 29)
                    mstore(parenTrackerPointer, or(and(mload(parenTrackerPointer), not(0xFFFF)), inputsBytePointer))
                }
                if (didOverflow) {
                    revert ParenInputOverflow();
                }
            }

            // We write sources RTL so they can run LTR.
            activeSource =
            // increment offset. We have 16 bits allocated to the offset and stop
            // processing at 0x100 so this never overflows into the actual source
            // data.
             bytes32(uint256(activeSource) + 0x20)
                // include the operand. The operand is assumed to be 16 bits, so we shift
                // it into the correct position.
                | OperandV2.unwrap(operand) << offset
                // include new op. The opcode is assumed to be 8 bits, so we shift it
                // into the correct position, beyond the operand.
                | bytes32(opcode << (offset + 0x18));
            assembly ("memory-safe") {
                mstore(activeSourcePointer, activeSource)
            }

            // We have filled the current source slot. Need to create a new active
            // source and fulfill the doubly linked list.
            if (offset == 0xe0) {
                state.activeSourcePtr = newActiveSourcePointer(activeSourcePointer);
            }
        }
    }

    /// @notice Finalises the current source by traversing the linked list of source
    /// slots, reordering opcodes from RTL to LTR at the top level, writing
    /// the source prefix, and registering the source in the sources builder.
    /// Resets per-source state for the next source via `resetSource`.
    /// @param state The parse state containing the active source to finalise.
    function endSource(ParseState memory state) internal pure {
        uint256 sourcesBuilder = state.sourcesBuilder;
        uint256 offset = sourcesBuilder >> 0xf0;

        // End is the number of top level words in the source, which is the
        // byte offset index + 1.
        uint256 end;
        uint256 topLevel0Offset = PARSE_STATE_TOP_LEVEL0_OFFSET;
        assembly ("memory-safe") {
            end := add(byte(0, mload(add(state, topLevel0Offset))), 1)
        }

        if (offset == 0xf0) {
            revert MaxSources();
        }
        // Follow the word counters to build the source with the correct
        // combination of LTR and RTL words. The stack needs to be built
        // LTR at the top level, so that as the evaluation proceeds LTR it
        // can reference previous items in subsequent items. However, the
        // stack is built RTL within each item, so that nested parens are
        // evaluated correctly similar to reverse polish notation.
        else {
            uint256 source;
            bool totalOpsOverflow;
            ParseStackTracker stackTracker = state.stackTracker;
            uint256 cursor = state.activeSourcePtr;
            uint256 topLevel0DataOffset = PARSE_STATE_TOP_LEVEL0_DATA_OFFSET;
            assembly ("memory-safe") {
                // find the end of the LL tail.
                let tailPointer := and(shr(0x10, mload(cursor)), 0xFFFF)
                for {} iszero(iszero(tailPointer)) {} {
                    cursor := tailPointer
                    tailPointer := and(shr(0x10, mload(cursor)), 0xFFFF)
                }

                // Move cursor to the end of the end of the LL tail item.
                // This is 4 bytes from the end of the EVM word, to compensate
                // for the offset and pointer positions.
                tailPointer := cursor
                cursor := add(cursor, 0x1C)
                // leave space for the source prefix in the bytecode output.
                let length := 4
                source := mload(0x40)
                // Move over the source 32 byte length and the 4 byte prefix.
                let writeCursor := add(source, 0x20)
                writeCursor := add(writeCursor, 4)

                let counterCursor := add(state, topLevel0DataOffset)
                for {
                    let i := 0
                    let wordsTotal := byte(0, mload(counterCursor))
                    let wordsRemaining := wordsTotal
                } lt(i, end) {
                    i := add(i, 1)
                    counterCursor := add(counterCursor, 1)
                    wordsTotal := byte(0, mload(counterCursor))
                    wordsRemaining := wordsTotal
                } {
                    length := add(length, mul(wordsTotal, 4))
                    {
                        // 4 bytes per source word.
                        let tailItemWordsRemaining := div(sub(cursor, tailPointer), 4)
                        // loop to the tail item that contains the start of the words
                        // that we need to copy.
                        for {} gt(wordsRemaining, tailItemWordsRemaining) {} {
                            wordsRemaining := sub(wordsRemaining, tailItemWordsRemaining)
                            tailPointer := and(mload(tailPointer), 0xFFFF)
                            tailItemWordsRemaining := 7
                            cursor := add(tailPointer, 0x1C)
                        }
                    }

                    // Now the words remaining is lte the words remaining in the
                    // tail item. Move the cursor back to the start of the words
                    // and copy the passed over bytes to the write cursor.
                    {
                        let forwardTailPointer := tailPointer
                        let size := mul(wordsRemaining, 4)
                        cursor := sub(cursor, size)
                        mstore(writeCursor, mload(cursor))
                        writeCursor := add(writeCursor, size)

                        // Redefine wordsRemaining to be the number of words
                        // left to copy.
                        wordsRemaining := sub(wordsTotal, wordsRemaining)
                        // Move over whole tail items.
                        for {} gt(wordsRemaining, 7) {} {
                            wordsRemaining := sub(wordsRemaining, 7)
                            // Follow the forward tail pointer.
                            forwardTailPointer := and(shr(0x10, mload(forwardTailPointer)), 0xFFFF)
                            mstore(writeCursor, mload(forwardTailPointer))
                            writeCursor := add(writeCursor, 0x1c)
                        }
                        // Move over the remaining words in the tail item.
                        if gt(wordsRemaining, 0) {
                            forwardTailPointer := and(shr(0x10, mload(forwardTailPointer)), 0xFFFF)
                            mstore(writeCursor, mload(forwardTailPointer))
                            writeCursor := add(writeCursor, mul(wordsRemaining, 4))
                        }
                    }
                }
                // The total ops count across all top-level items must
                // fit in a single byte. `length` includes the 4-byte
                // prefix, so `div(length, 4) - 1` is the opcode count.
                totalOpsOverflow := gt(sub(div(length, 4), 1), 0xFF)

                // Store the bytes length in the source.
                mstore(source, length)
                // Store the opcodes length and stack tracker in the source
                // prefix.
                let prefixWritePointer := add(source, 4)
                mstore(
                    prefixWritePointer,
                    or(
                        and(mload(prefixWritePointer), not(0xFFFFFFFF)),
                        or(shl(0x18, sub(div(length, 4), 1)), stackTracker)
                    )
                )

                // Round up to the nearest 32 bytes to realign memory.
                mstore(0x40, and(add(writeCursor, 0x1f), not(0x1f)))
            }
            if (totalOpsOverflow) {
                revert SourceTotalOpsOverflow();
            }

            //slither-disable-next-line incorrect-shift
            state.sourcesBuilder =
            //forge-lint: disable-next-line(incorrect-shift)
                ((offset + 0x10) << 0xf0) | (source << offset) | (sourcesBuilder & ((1 << offset) - 1));

            // Reset source as we're done with this one.
            state.fsm &= ~FSM_ACTIVE_SOURCE_MASK;
            state.resetSource();
        }
    }

    /// @notice Assembles the final bytecode from all completed sources. Writes the
    /// source count, relative pointers, and copies each source's opcodes into
    /// a single contiguous byte array. Reverts if a source is still active.
    /// @param state The parse state containing all completed sources.
    /// @return bytecode The assembled bytecode as a contiguous byte array.
    function buildBytecode(ParseState memory state) internal pure returns (bytes memory bytecode) {
        unchecked {
            uint256 sourcesBuilder = state.sourcesBuilder;
            uint256 offsetEnd = (sourcesBuilder >> 0xf0);

            // Somehow the parser state for the active source was not reset
            // correctly, or the finalised offset is dangling. This implies that
            // we are building the overall sources array while still trying to
            // build one of the individual sources. This is a bug in the parser.
            uint256 activeSource;
            {
                uint256 activeSourcePointer = state.activeSourcePtr;
                assembly ("memory-safe") {
                    activeSource := mload(activeSourcePointer)
                }
            }

            if (activeSource != EMPTY_ACTIVE_SOURCE) {
                revert DanglingSource();
            }

            uint256 cursor;
            uint256 sourcesCount;
            uint256 sourcesStart;
            assembly ("memory-safe") {
                cursor := mload(0x40)
                bytecode := cursor
                // Move past the bytecode length, we will write this at the end.
                cursor := add(cursor, 0x20)

                // First byte is the number of sources.
                sourcesCount := div(offsetEnd, 0x10)
                mstore8(cursor, sourcesCount)
                cursor := add(cursor, 1)

                let pointersCursor := cursor

                // Skip past the pointer space. We'll back fill it.
                // Divide offsetEnd to convert from a bit to a byte shift.
                cursor := add(cursor, div(offsetEnd, 8))
                sourcesStart := cursor

                // Write total bytes length into bytecode. We do ths and handle
                // the allocation in this same assembly block for memory safety
                // for the compiler optimiser.
                let sourcesLength := 0
                let sourcePointers := 0
                for { let offset := 0 } lt(offset, offsetEnd) { offset := add(offset, 0x10) } {
                    let currentSourcePointer := and(shr(offset, sourcesBuilder), 0xFFFF)
                    // add 4 byte prefix to the length of the sources, all as
                    // bytes.
                    sourcePointers := or(sourcePointers, shl(sub(0xf0, offset), sourcesLength))
                    let currentSourceLength := mload(currentSourcePointer)

                    // Put the reference source pointer and length into the
                    // prefix so that we can use them to copy the actual data
                    // into the bytecode.
                    let tmpPrefix := shl(0xe0, or(shl(0x10, currentSourcePointer), currentSourceLength))
                    mstore(add(sourcesStart, sourcesLength), tmpPrefix)
                    sourcesLength := add(sourcesLength, currentSourceLength)
                }
                mstore(pointersCursor, or(mload(pointersCursor), sourcePointers))
                mstore(bytecode, add(sourcesLength, sub(sub(sourcesStart, 0x20), bytecode)))

                // Round up to the nearest 32 bytes past cursor to realign and
                // allocate memory.
                mstore(0x40, and(add(add(add(0x20, mload(bytecode)), bytecode), 0x1f), not(0x1f)))
            }

            // Loop over the sources and write them into the bytecode. Perhaps
            // there is a more efficient way to do this in the future that won't
            // cause each source to be written twice in memory.
            for (uint256 i = 0; i < sourcesCount; i++) {
                Pointer sourcePointer;
                uint256 length;
                Pointer targetPointer;
                assembly ("memory-safe") {
                    let relativePointer := and(mload(add(bytecode, add(3, mul(i, 2)))), 0xFFFF)
                    targetPointer := add(sourcesStart, relativePointer)
                    let tmpPrefix := mload(targetPointer)
                    sourcePointer := add(0x20, shr(0xf0, tmpPrefix))
                    length := and(shr(0xe0, tmpPrefix), 0xFFFF)
                }
                LibMemCpy.unsafeCopyBytesTo(sourcePointer, targetPointer, length);
            }
        }
    }

    /// @notice Builds the final constants array by traversing the constants linked
    /// list from head to tail and writing values in reverse so that indices
    /// in the source bytecode reference the correct positions.
    /// @param state The parse state containing the constants builder.
    /// @return constants The final constants array ordered by their stable
    /// indices in the source bytecode.
    function buildConstants(ParseState memory state) internal pure returns (bytes32[] memory constants) {
        uint256 constantsHeight = state.constantsBuilder & 0xFFFF;
        uint256 tailPtr = state.constantsBuilder >> 0x10;

        assembly ("memory-safe") {
            let cursor := mload(0x40)
            constants := cursor
            mstore(cursor, constantsHeight)
            let end := cursor
            // Move the cursor to the end of the array. Write in reverse order
            // of the linked list traversal so that the constants are built
            // according to the stable indexes in the source from the linked
            // list base.
            cursor := add(cursor, mul(constantsHeight, 0x20))
            // Allocate one word past the cursor. This will be just after the
            // length if the constants array is empty. Otherwise it will be
            // just after the last constant.
            mstore(0x40, add(cursor, 0x20))
            // It MUST be equivalent to say that the cursor is above the end,
            // and that we are following tail pointers until they point to 0,
            // and that the cursor is moving as far as the constants height.
            // This is ensured by the fact that the constants height is only
            // incremented when a new constant is added to the linked list.
            for {} gt(cursor, end) {
                // Next item in the linked list.
                cursor := sub(cursor, 0x20)
                // tail pointer in tail keys is the low 16 bits under the
                // fingerprint, which is different from the tail pointer in
                // the constants builder, where it sits above the constants
                // height.
                tailPtr := and(mload(tailPtr), 0xFFFF)
            } {
                // Store the values not the keys.
                mstore(cursor, mload(add(tailPtr, 0x20)))
            }
        }
    }

    /// @notice The parse system packs memory pointers into 16 bits throughout its
    /// linked list structures (active source slots, paren tracker, line
    /// tracker, sources builder, constants builder, stack names). This is
    /// safe as long as all memory allocated during parsing stays below
    /// 0x10000. If the free memory pointer reaches or exceeds that limit,
    /// any pointer stored after the overflow was silently truncated,
    /// corrupting the linked lists and producing invalid bytecode.
    ///
    /// This check MUST run after any complete parse operation. Callers that
    /// use `LibParse.parse` or `LibParsePragma.parsePragma` through a
    /// concrete contract should apply this check (or the
    /// `checkParseMemoryOverflow` modifier) after the call returns.
    function checkParseMemoryOverflow() internal pure {
        uint256 freeMemoryPointer;
        assembly ("memory-safe") {
            freeMemoryPointer := mload(0x40)
        }
        if (freeMemoryPointer >= 0x10000) {
            revert ParseMemoryOverflow(freeMemoryPointer);
        }
    }
}
