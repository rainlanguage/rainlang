// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {LibBytes, Pointer} from "rain.solmem/lib/LibBytes.sol";

// AuthoringMetaV2 exported for convenience.
//forge-lint: disable-next-line(unused-import)
import {ISubParserV4, AuthoringMetaV2} from "rain.interpreter.interface/interface/ISubParserV4.sol";
import {LibSubParse, ParseState} from "../lib/parse/LibSubParse.sol";
import {CMASK_RHS_WORD_TAIL} from "rain.string/lib/parse/LibParseCMask.sol";
import {LibParse, OperandV2} from "../lib/parse/LibParse.sol";
import {LibParseMeta} from "rain.interpreter.interface/lib/parse/LibParseMeta.sol";
import {LibParseOperand} from "../lib/parse/LibParseOperand.sol";
import {IDescribedByMetaV1} from "rain.metadata/interface/IDescribedByMetaV1.sol";
import {IParserToolingV1} from "rain.sol.codegen/interface/IParserToolingV1.sol";
import {ISubParserToolingV1} from "rain.sol.codegen/interface/ISubParserToolingV1.sol";
import {SubParserIndexOutOfBounds} from "../error/ErrSubParse.sol";

/// @dev This is a placeholder for the subparser function pointers.
/// The subparser function pointers are a list of 16 bit function pointers,
/// where each subparser function is responsible for parsing a particular
/// word into a an opcode that will be used by the main parser to build the
/// final bytecode.
bytes constant SUB_PARSER_WORD_PARSERS = hex"";

/// @dev This is a placeholder for the subparser meta bytes.
/// The subparser meta bytes are the same structure as the main parser meta
/// bytes. The exact same process of hashing, blooming, fingerprinting and index
/// lookup applies to the subparser meta bytes as the main parser meta bytes.
bytes constant SUB_PARSER_PARSE_META = hex"";

/// @dev This is a placeholder for the int that encodes pointers to operand
/// parsers.
bytes constant SUB_PARSER_OPERAND_HANDLERS = hex"";

/// @dev This is a placeholder for the int that encodes pointers to literal
/// parsers.
bytes constant SUB_PARSER_LITERAL_PARSERS = hex"";

/// Base implementation of `ISubParserV4`. Inherit from this contract and
/// override the virtual functions to align all the relevant pointers and
/// metadata bytes so that it can actually run.
/// The basic workflow for subparsing via this contract is:
/// - The main parser will call `subParse` with the subparser's compatibility
///   version and the data to parse.
/// - The subparser will check the compatibility is an exact match and revert if
///   not. This is the simplest and most conservative approach, if there's a new
///   compatibility version, a new version of the subparser will need to be
///   deployed even if the upstream changes are backwards compatible.
/// - The subparser will then parse the data, using the `subParserParseMeta`
///   function to get the metadata bytes, which must be overridden by the child
///   contract in order to be useful. The sub parser meta bytes are constructed
///   exactly the same as the main parser meta bytes, so the same types and libs
///   can be used to build them. The key difference is that the index of each
///   word in the authoring meta maps to a _parser_ function pointer, rather
///   than a _handler_ function pointer. What this means is that the function
///   at index N of `subParserFunctionPointers` is responsible for parsing
///   whatever data the main parser has passed to `subParse` into whatever the
///   final output of the subparser is. For example, the 5th parser function
///   might convert some word string `"foo"` into the bytecode that represents
///   an extern call on the main interpreter into the contract that provides
///   that extern logic. This decoupling allows any subparser function to
///   generate any runtime behaviour at all, provided it knows how to construct
///   the opcode for it.
/// - Currently the subparse handles literals and operands in the same way as
///   the main parser, but this may change in future. Likely that there will be
///   dedicated "sub literal" and "sub word" concepts, that should be more
///   composable than the current approach.
/// - The final result of the subparser is returned as a tuple of success,
///   bytecode and constants. The success flag is used to indicate whether the
///   subparser was able to parse the data, and the bytecode and constants are
///   the same as the main parser, and are used to construct the final bytecode
///   of the main parser. The expectation on failure is that there may be some
///   other subparser that can parse the data, so the main parser will handle
///   fallback logic.
abstract contract BaseRainlangSubParser is
    ERC165,
    ISubParserV4,
    IDescribedByMetaV1,
    IParserToolingV1,
    ISubParserToolingV1
{
    using LibBytes for bytes;
    using LibParse for ParseState;
    using LibParseMeta for ParseState;
    using LibParseOperand for ParseState;

    /// Overrideable function to allow implementations to define their parse
    /// meta bytes.
    //slither-disable-next-line dead-code
    function subParserParseMeta() internal pure virtual returns (bytes memory) {
        return SUB_PARSER_PARSE_META;
    }

    /// Overrideable function to allow implementations to define their function
    /// pointers to each sub parser.
    //slither-disable-next-line dead-code
    function subParserWordParsers() internal pure virtual returns (bytes memory) {
        return SUB_PARSER_WORD_PARSERS;
    }

    /// Overrideable function to allow implementations to define their operand
    /// handlers.
    //slither-disable-next-line dead-code
    function subParserOperandHandlers() internal pure virtual returns (bytes memory) {
        return SUB_PARSER_OPERAND_HANDLERS;
    }

    /// Overrideable function to allow implementations to define their literal
    /// parsers.
    //slither-disable-next-line dead-code
    function subParserLiteralParsers() internal pure virtual returns (bytes memory) {
        return SUB_PARSER_LITERAL_PARSERS;
    }

    /// @notice Overrideable function to allow implementations to define their
    /// literal dispatch matching. This is optional, and if not overridden
    /// simply won't attempt to parse any literals. This is usually what you
    /// want, as the main parser will handle common literals and the subparser
    /// can focus on words, which is the more common case.
    /// @param cursor The cursor to the memory location of the start of the
    /// dispatch data.
    /// @param end The cursor to the memory location of the end of the dispatch
    /// data.
    /// @return success Whether the dispatch was successfully matched. If the
    /// sub parser does not recognise the dispatch data, it should return false.
    /// The main parser MAY fallback to other sub parsers, so this is not
    /// necessarily a failure condition.
    /// @return index The index of the sub parser literal parser to use. If
    /// success is true, this MUST match the position of the function pointer in
    /// the bytes returned by `subParserLiteralParsers`.
    /// @return value The value of the dispatch data, which is passed to the
    /// sub parser literal parser. This MAY be zero if the sub parser does not
    /// need to use the dispatch data. The interpretation of this value is
    /// entirely up to the sub parser.
    //slither-disable-next-line dead-code
    function matchSubParseLiteralDispatch(uint256 cursor, uint256 end)
        internal
        view
        virtual
        returns (bool success, uint256 index, bytes32 value)
    {
        (cursor, end);
        success = false;
        index = 0;
        value = 0;
    }

    /// @notice A basic implementation of sub parsing literals that uses encoded
    /// function pointers to dispatch everything necessary in O(1) and allows
    /// for the child contract to override all relevant functions with some
    /// modest boilerplate.
    /// This is virtual but the expectation is that it generally DOES NOT need
    /// to be overridden, as the function pointers and metadata bytes are all
    /// that need to be changed to implement a new subparser.
    /// @inheritdoc ISubParserV4
    function subParseLiteral2(bytes memory data) external view virtual returns (bool, bytes32) {
        (uint256 dispatchStart, uint256 bodyStart, uint256 bodyEnd) = LibSubParse.consumeSubParseLiteralInputData(data);

        (bool success, uint256 index, bytes32 dispatchValue) = matchSubParseLiteralDispatch(dispatchStart, bodyStart);

        if (success) {
            function(bytes32, uint256, uint256) internal pure returns (bytes32) subParser;
            bytes memory localSubParserLiteralParsers = subParserLiteralParsers();
            uint256 parsersLength = localSubParserLiteralParsers.length / 2;
            if (index >= parsersLength) {
                revert SubParserIndexOutOfBounds(index, parsersLength);
            }
            assembly ("memory-safe") {
                subParser := and(mload(add(localSubParserLiteralParsers, mul(add(index, 1), 2))), 0xFFFF)
            }
            return (true, subParser(dispatchValue, bodyStart, bodyEnd));
        } else {
            return (false, 0);
        }
    }

    /// @notice A basic implementation of sub parsing words that uses encoded function
    /// pointers to dispatch everything necessary in O(1) and allows for the
    /// child contract to override all relevant functions with some modest
    /// boilerplate.
    /// This is virtual but the expectation is that it generally DOES NOT need
    /// to be overridden, as the function pointers and metadata bytes are all
    /// that need to be changed to implement a new subparser.
    /// @inheritdoc ISubParserV4
    function subParseWord2(bytes memory data) external pure virtual returns (bool, bytes memory, bytes32[] memory) {
        (uint256 constantsHeight, uint256 ioByte, ParseState memory state) =
            LibSubParse.consumeSubParseWordInputData(data, subParserParseMeta(), subParserOperandHandlers());
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        uint256 end = cursor + state.data.length;

        bytes32 word;
        (cursor, word) = LibParse.parseWord(cursor, end, CMASK_RHS_WORD_TAIL);
        (bool exists, uint256 index) = LibParseMeta.lookupWord(state.meta, word);
        if (exists) {
            OperandV2 operand = state.handleOperand(index);
            function(uint256, uint256, OperandV2) internal pure returns (bool, bytes memory, bytes32[] memory) subParser;
            bytes memory localSubParserWordParsers = subParserWordParsers();
            uint256 parsersLength = localSubParserWordParsers.length / 2;
            if (index >= parsersLength) {
                revert SubParserIndexOutOfBounds(index, parsersLength);
            }
            assembly ("memory-safe") {
                subParser := and(mload(add(localSubParserWordParsers, mul(add(index, 1), 2))), 0xFFFF)
            }
            return subParser(constantsHeight, ioByte, operand);
        } else {
            return (false, "", new bytes32[](0));
        }
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(ISubParserV4).interfaceId || interfaceId == type(IDescribedByMetaV1).interfaceId
            || interfaceId == type(IParserToolingV1).interfaceId || interfaceId == type(ISubParserToolingV1).interfaceId
            || super.supportsInterface(interfaceId);
    }
}
