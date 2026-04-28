// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {LibParseState, ParseState, SUB_PARSER_POINTER_SHIFT} from "./LibParseState.sol";
import {
    OPCODE_UNKNOWN,
    OPCODE_EXTERN,
    OPCODE_CONSTANT,
    OPCODE_CONTEXT,
    OperandV2
} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibBytecode, Pointer} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";
import {ISubParserV4} from "rain.interpreter.interface/interface/ISubParserV4.sol";
import {BadSubParserResult, UnknownWord, UnsupportedLiteralType} from "../../error/ErrParse.sol";
import {IInterpreterExternV4, LibExtern, EncodedExternDispatchV2} from "../extern/LibExtern.sol";
import {
    ExternDispatchConstantsHeightOverflow,
    ConstantOpcodeConstantsHeightOverflow,
    ContextGridOverflow,
    SubParseLiteralDispatchLengthOverflow
} from "../../error/ErrSubParse.sol";
import {LibMemCpy} from "rain.solmem/lib/LibMemCpy.sol";
import {LibParseError} from "./LibParseError.sol";

/// @title LibSubParse
/// @notice Handles delegation of unknown words and literals to external sub-parser
/// contracts registered via `using-words-from`.
///
/// Trust model: sub-parsers are fully trusted by the Rainlang author who
/// opted into them. A sub-parser can return arbitrary bytecode (opcode,
/// operand, IO byte) and constants. The only parse-time validation is that
/// the returned bytecode is exactly 4 bytes (`BadSubParserResult`). All
/// other safety comes from the integrity check that runs on the complete
/// bytecode after all sub-parsing is done — invalid opcodes, stack
/// mismatches, or malformed operands will be caught there.
library LibSubParse {
    using LibParseState for ParseState;
    using LibParseError for ParseState;

    /// @notice Sub parse a word into a context grid position. The column and row are
    /// encoded as single bytes in the operand, so values MUST be <= 255.
    /// Reverts with `ContextGridOverflow` if either value exceeds uint8.
    /// @param column The column index in the context grid. Must fit in uint8.
    /// @param row The row index in the context grid. Must fit in uint8.
    /// @return Whether the sub parse succeeded.
    /// @return The bytecode for the context opcode.
    /// @return The constants array (empty for context ops).
    function subParserContext(uint256 column, uint256 row)
        internal
        pure
        returns (bool, bytes memory, bytes32[] memory)
    {
        if (column > type(uint8).max || row > type(uint8).max) {
            revert ContextGridOverflow(column, row);
        }
        bytes memory bytecode;
        uint256 opIndex = OPCODE_CONTEXT;
        assembly ("memory-safe") {
            // Allocate the bytecode.
            // This is an UNALIGNED allocation. The 4-byte bytecode is
            // returned to the caller and copied directly over an opcode
            // slot in the main bytecode, so it never reaches Solidity
            // code that expects 32-byte aligned memory.
            bytecode := mload(0x40)
            mstore(0x40, add(bytecode, 0x24))

            mstore8(add(bytecode, 0x23), column)
            mstore8(add(bytecode, 0x22), row)

            // 0 inputs 1 output.
            mstore8(add(bytecode, 0x21), 0x10)

            mstore8(add(bytecode, 0x20), opIndex)

            // Write the length of the bytes.
            mstore(bytecode, 4)
        }

        bytes32[] memory constants;
        assembly ("memory-safe") {
            constants := mload(0x40)
            mstore(0x40, add(constants, 0x20))
            mstore(constants, 0)
        }

        return (true, bytecode, constants);
    }

    /// @notice Sub parse a value into the bytecode that will run on the interpreter to
    /// push the given value onto the stack, using the constant opcode at eval.
    /// @param constantsHeight The current height of the constants array.
    /// @param value The constant value to push onto the stack.
    /// @return Whether the sub parse succeeded.
    /// @return The bytecode for the constant opcode.
    /// @return The constants array containing the value.
    function subParserConstant(uint256 constantsHeight, bytes32 value)
        internal
        pure
        returns (bool, bytes memory, bytes32[] memory)
    {
        if (constantsHeight > type(uint16).max) {
            revert ConstantOpcodeConstantsHeightOverflow(constantsHeight);
        }
        // Build a constant opcode that the interpreter will run itself.
        bytes memory bytecode;
        uint256 opIndex = OPCODE_CONSTANT;
        assembly ("memory-safe") {
            // Allocate the bytecode.
            // This is an UNALIGNED allocation. The 4-byte bytecode is
            // returned to the caller and copied directly over an opcode
            // slot in the main bytecode, so it never reaches Solidity
            // code that expects 32-byte aligned memory.
            bytecode := mload(0x40)
            mstore(0x40, add(bytecode, 0x24))

            // It's most efficient to store the constants height first, as it
            // is in theory multibyte (although it's not expected to be).
            // This also has the effect of zeroing out the inputs, which is what
            // we want, as long as the main parser respects the constants height
            // never being more than 2 bytes.
            mstore(add(bytecode, 4), constantsHeight)

            // 0 inputs 1 output.
            mstore8(add(bytecode, 0x21), 0x10)

            // Main opcode is constant.
            mstore8(add(bytecode, 0x20), opIndex)

            // Write the length of the bytes.
            mstore(bytecode, 4)
        }

        bytes32[] memory constants;
        assembly ("memory-safe") {
            constants := mload(0x40)
            mstore(0x40, add(constants, 0x40))
            mstore(constants, 1)
            mstore(add(constants, 0x20), value)
        }

        return (true, bytecode, constants);
    }

    /// @notice Sub parse a known extern opcode index into the bytecode that will run
    /// on the interpreter to call the given extern contract. This requires the
    /// parsing has already matched a word to the extern opcode index, so it
    /// implies the parse meta has been traversed and the parse index has been
    /// mapped to an extern opcode index somehow.
    /// @param extern The extern contract to call at eval time.
    /// @param constantsHeight The current height of the constants array.
    /// @param ioByte The IO byte encoding inputs and outputs for the opcode.
    /// MUST fit in 8 bits. Written via `mstore8` which silently truncates
    /// to the least significant byte if wider.
    /// @param operand The operand for the extern dispatch.
    /// @param opcodeIndex The opcode index on the extern contract. MUST fit
    /// in 16 bits. Passed to `encodeExternDispatch` which does not validate
    /// the range — wider values silently corrupt the encoding.
    /// @return Whether the sub parse succeeded.
    /// @return The bytecode for the extern opcode.
    /// @return The constants array containing the encoded extern dispatch.
    function subParserExtern(
        IInterpreterExternV4 extern,
        uint256 constantsHeight,
        uint256 ioByte,
        OperandV2 operand,
        uint256 opcodeIndex
    ) internal pure returns (bool, bytes memory, bytes32[] memory) {
        // The constants height is an error check because the main parser can
        // provide two bytes for it. Everything else is expected to be more
        // directly controlled by the subparser itself.
        if (constantsHeight > type(uint16).max) {
            revert ExternDispatchConstantsHeightOverflow(constantsHeight);
        }
        // Build an extern call that dials back into the current contract at eval
        // time with the current opcode index.
        bytes memory bytecode;
        uint256 opIndex = OPCODE_EXTERN;
        assembly ("memory-safe") {
            // Allocate the bytecode.
            // This is an UNALIGNED allocation. The 4-byte bytecode is
            // returned to the caller and copied directly over an opcode
            // slot in the main bytecode, so it never reaches Solidity
            // code that expects 32-byte aligned memory.
            bytecode := mload(0x40)
            mstore(0x40, add(bytecode, 0x24))
            mstore(add(bytecode, 4), constantsHeight)
            // The IO byte is inputs merged with outputs.
            mstore8(add(bytecode, 0x21), ioByte)
            // Main opcode is extern, to call back into current contract.
            mstore8(add(bytecode, 0x20), opIndex)
            // The bytes length is 4.
            mstore(bytecode, 4)
        }

        bytes32 externDispatch = EncodedExternDispatchV2.unwrap(
            LibExtern.encodeExternCall(extern, LibExtern.encodeExternDispatch(opcodeIndex, operand))
        );

        bytes32[] memory constants;
        assembly ("memory-safe") {
            constants := mload(0x40)
            mstore(0x40, add(constants, 0x40))
            mstore(constants, 1)
            mstore(add(constants, 0x20), externDispatch)
        }

        return (true, bytecode, constants);
    }

    /// @notice Iterates over a slice of bytecode ops and attempts to resolve any
    /// unknown opcodes by delegating to the registered sub parsers.
    /// @param state The current parse state containing sub parser references.
    /// @param cursor The memory pointer to the start of the bytecode slice.
    /// @param end The memory pointer to the end of the bytecode slice.
    function subParseWordSlice(ParseState memory state, uint256 cursor, uint256 end) internal view {
        unchecked {
            for (; cursor < end; cursor += 4) {
                uint256 memoryAtCursor;
                assembly ("memory-safe") {
                    memoryAtCursor := mload(cursor)
                }
                if (memoryAtCursor >> 0xf8 == OPCODE_UNKNOWN) {
                    bytes32 deref = state.subParsers;
                    while (deref != 0) {
                        ISubParserV4 subParser = ISubParserV4(address(uint160(uint256(deref))));
                        assembly ("memory-safe") {
                            deref := mload(shr(SUB_PARSER_POINTER_SHIFT, deref))
                        }

                        // Subparse data is a fixed length header that provides the
                        // subparser some minimal additional contextual information
                        // then the rest of the data is the original string that the
                        // main parser could not understand.
                        // The header is structured and versioned according to
                        // the compatibility version.
                        bytes memory data;
                        // The operand of the unknown opcode directly points at the
                        // data that we need to subparse.
                        assembly ("memory-safe") {
                            data := and(shr(0xe0, memoryAtCursor), 0xFFFF)
                        }
                        // We just need to fill in the header.
                        {
                            uint256 constantsBuilder = state.constantsBuilder;
                            assembly ("memory-safe") {
                                let header :=
                                    shl(
                                        0xe8,
                                        or(
                                            // IO byte is the second byte of the unknown op.
                                            byte(1, memoryAtCursor),
                                            // Constants builder height is the low 16 bits.
                                            shl(8, and(constantsBuilder, 0xFFFF))
                                        )
                                    )

                                let headerPtr := add(data, 0x20)
                                mstore(headerPtr, or(header, and(mload(headerPtr), not(shl(0xe8, 0xFFFFFF)))))
                            }
                        }

                        (bool success, bytes memory subBytecode, bytes32[] memory subConstants) =
                            subParser.subParseWord2(data);
                        if (success) {
                            // The sub bytecode must be exactly 4 bytes to
                            // represent an op.
                            if (subBytecode.length != 4) {
                                revert BadSubParserResult(subBytecode);
                            }

                            {
                                // Copy the sub bytecode over the unknown op.
                                uint256 mask = 0xFFFFFFFF << 0xe0;
                                assembly ("memory-safe") {
                                    mstore(
                                        cursor,
                                        or(and(memoryAtCursor, not(mask)), and(mload(add(subBytecode, 0x20)), mask))
                                    )
                                }
                            }

                            for (uint256 i; i < subConstants.length; ++i) {
                                state.pushConstantValue(subConstants[i]);
                            }

                            // Stop looping over sub parsers now.
                            break;
                        }
                    }
                }

                // If the op was not replaced, then we need to error because we have
                // no idea what it is.
                assembly ("memory-safe") {
                    memoryAtCursor := mload(cursor)
                }
                if (memoryAtCursor >> 0xf8 == OPCODE_UNKNOWN) {
                    string memory word;
                    // The operand of the unknown opcode directly points at the
                    // unknown word subparsing data.
                    assembly ("memory-safe") {
                        word := and(shr(0xe0, memoryAtCursor), 0xFFFF)
                        // Zero out the sub parsing header data other than the
                        // string length.
                        mstore(add(word, 3), 0)
                        // Use the 2 byte length in the sub parse data as the
                        // string length for the error.
                        word := add(word, 5)
                    }
                    revert UnknownWord(word);
                }
            }
        }
    }

    /// @notice Resolves all unknown words across every source in the given bytecode
    /// by calling `subParseWordSlice` for each source, then returns the
    /// mutated bytecode and the final constants array.
    /// @param state The current parse state containing sub parser references.
    /// @param bytecode The full bytecode containing all sources to resolve.
    /// @return The mutated bytecode with unknown ops resolved.
    /// @return The final constants array after all sub parses.
    function subParseWords(ParseState memory state, bytes memory bytecode)
        internal
        view
        returns (bytes memory, bytes32[] memory)
    {
        unchecked {
            uint256 sourceCount = LibBytecode.sourceCount(bytecode);
            for (uint256 sourceIndex; sourceIndex < sourceCount; ++sourceIndex) {
                // Start cursor at the pointer to the source.
                uint256 cursor = Pointer.unwrap(LibBytecode.sourcePointer(bytecode, sourceIndex)) + 4;
                uint256 end = cursor + (LibBytecode.sourceOpsCount(bytecode, sourceIndex) * 4);
                subParseWordSlice(state, cursor, end);
            }
            return (bytecode, state.buildConstants());
        }
    }

    /// @notice Delegates literal parsing to registered sub parsers. Packs the dispatch
    /// and body regions into a single `bytes` payload and tries each sub parser
    /// until one succeeds, reverting if none can handle the literal type.
    /// @param state The current parse state containing sub parser references.
    /// @param dispatchStart Memory pointer to the start of the dispatch region.
    /// @param dispatchEnd Memory pointer to the end of the dispatch region.
    /// @param bodyStart Memory pointer to the start of the body region.
    /// @param bodyEnd Memory pointer to the end of the body region.
    /// @return The parsed literal value as a bytes32.
    function subParseLiteral(
        ParseState memory state,
        uint256 dispatchStart,
        uint256 dispatchEnd,
        uint256 bodyStart,
        uint256 bodyEnd
    ) internal view returns (bytes32) {
        unchecked {
            // Build the data for the subparser.
            bytes memory data;
            {
                uint256 copyPointer;
                uint256 dispatchLength = dispatchEnd - dispatchStart;
                if (dispatchLength > type(uint16).max) {
                    revert SubParseLiteralDispatchLengthOverflow(dispatchLength);
                }
                uint256 bodyLength = bodyEnd - bodyStart;
                {
                    uint256 dataLength = 2 + dispatchLength + bodyLength;
                    assembly ("memory-safe") {
                        data := mload(0x40)
                        // Round up to 32-byte alignment to maintain
                        // Solidity's free memory pointer invariant.
                        mstore(0x40, and(add(add(data, add(dataLength, 0x20)), 0x1f), not(0x1f)))
                        mstore(add(data, 2), dispatchLength)
                        mstore(data, dataLength)
                        copyPointer := add(data, 0x22)
                    }
                }
                LibMemCpy.unsafeCopyBytesTo(Pointer.wrap(dispatchStart), Pointer.wrap(copyPointer), dispatchLength);
                LibMemCpy.unsafeCopyBytesTo(
                    Pointer.wrap(bodyStart), Pointer.wrap(copyPointer + dispatchLength), bodyLength
                );
            }

            bytes32 deref = state.subParsers;
            while (deref != 0) {
                ISubParserV4 subParser = ISubParserV4(address(uint160(uint256(deref))));
                assembly ("memory-safe") {
                    deref := mload(shr(SUB_PARSER_POINTER_SHIFT, deref))
                }

                (bool success, bytes32 value) = subParser.subParseLiteral2(data);
                if (success) {
                    return value;
                }
            }

            revert UnsupportedLiteralType(state.parseErrorOffset(dispatchStart));
        }
    }

    /// @notice Unpacks the sub-parse word input data by extracting the constants
    /// height, IO byte, and operand values from the header, then constructs
    /// a fresh `ParseState` from the remaining word string and provided meta.
    /// @param data The raw sub-parse input data containing the header and
    /// word string.
    /// @param meta The parser meta bytes for the new parse state.
    /// @param operandHandlers The operand handler bytes for the new parse
    /// state.
    /// @return constantsHeight The constants height from the header.
    /// @return ioByte The IO byte from the header.
    /// @return state The newly constructed parse state.
    function consumeSubParseWordInputData(bytes memory data, bytes memory meta, bytes memory operandHandlers)
        internal
        pure
        returns (uint256 constantsHeight, uint256 ioByte, ParseState memory state)
    {
        bytes32[] memory operandValues;
        assembly ("memory-safe") {
            // Pull the header out into EVM stack items.
            constantsHeight := and(mload(add(data, 2)), 0xFFFF)
            ioByte := and(mload(add(data, 3)), 0xFF)

            // Mutate the data to no longer have a header.
            let newLength := and(mload(add(data, 5)), 0xFFFF)
            data := add(data, 5)
            mstore(data, newLength)
            operandValues := add(data, add(newLength, 0x20))
        }
        // Literal parsers are empty for the sub parser as the main parser should
        // be handling all literals in operands. The sub parser handles literal
        // parsing as a dedicated interface separately.
        state = LibParseState.newState(data, meta, operandHandlers, "");
        state.operandValues = operandValues;
    }

    /// @notice Unpacks the sub-parse literal input data by extracting memory pointers
    /// for the dispatch and body regions from the encoded `bytes` payload.
    /// @param data The raw sub-parse literal input data.
    /// @return dispatchStart Memory pointer to the start of the dispatch
    /// region.
    /// @return bodyStart Memory pointer to the start of the body region.
    /// @return bodyEnd Memory pointer to the end of the body region.
    function consumeSubParseLiteralInputData(bytes memory data)
        internal
        pure
        returns (uint256 dispatchStart, uint256 bodyStart, uint256 bodyEnd)
    {
        assembly ("memory-safe") {
            let dispatchLength := and(mload(add(data, 2)), 0xFFFF)
            dispatchStart := add(data, 0x22)
            bodyStart := add(dispatchStart, dispatchLength)
            bodyEnd := add(data, add(0x20, mload(data)))
        }
    }
}
