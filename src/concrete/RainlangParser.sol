// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";

import {LibParse} from "../lib/parse/LibParse.sol";

import {PragmaV1} from "rain.interpreter.interface/interface/IParserPragmaV1.sol";
import {LibParseState, ParseState} from "../lib/parse/LibParseState.sol";
import {LibParsePragma} from "../lib/parse/LibParsePragma.sol";
import {LibAllStandardOps} from "../lib/op/LibAllStandardOps.sol";
import {LibBytes, Pointer} from "rain.solmem/lib/LibBytes.sol";
import {LibParseInterstitial} from "../lib/parse/LibParseInterstitial.sol";
import {
    LITERAL_PARSER_FUNCTION_POINTERS,

    // Exported for convenience.
    //forge-lint: disable-next-line(unused-import)
    BYTECODE_HASH as PARSER_BYTECODE_HASH,
    OPERAND_HANDLER_FUNCTION_POINTERS,
    PARSE_META,

    // Exported for convenience.
    //forge-lint: disable-next-line(unused-import)
    PARSE_META_BUILD_DEPTH
} from "../generated/RainlangParser.pointers.sol";
import {IParserToolingV1} from "rain.sol.codegen/interface/IParserToolingV1.sol";

/// @title RainlangParser
/// @notice Converts Rainlang text to bytecode.
/// @dev The parser implementation. NOT intended to be called directly so
/// intentionally does NOT implement various interfaces. The expression deployer
/// calls into this contract and exposes the relevant interfaces, with additional
/// safety and integrity checks.
contract RainlangParser is ERC165, IParserToolingV1 {
    using LibParse for ParseState;
    using LibParseState for ParseState;
    using LibParsePragma for ParseState;
    using LibParseInterstitial for ParseState;
    using LibBytes for bytes;

    /// Runs `LibParseState.checkParseMemoryOverflow` after the modified
    /// function body completes, reverting if the free memory pointer
    /// reached or exceeded 0x10000 during parsing.
    modifier checkParseMemoryOverflow() {
        _;
        LibParseState.checkParseMemoryOverflow();
    }

    /// @notice Parses Rainlang source `data` into bytecode and constants. Called by
    /// the expression deployer. Does not perform integrity checks — those are
    /// the deployer's responsibility.
    /// @param data The Rainlang source bytes to parse.
    /// @return The compiled bytecode.
    /// @return The constants array extracted during parsing.
    function unsafeParse(bytes memory data)
        external
        view
        virtual
        checkParseMemoryOverflow
        returns (bytes memory, bytes32[] memory)
    {
        // The return is used by returning it, so this is a false positive.
        //slither-disable-next-line unused-return
        return LibParseState.newState(
                data, parseMeta(), operandHandlerFunctionPointers(), literalParserFunctionPointers()
            ).parse();
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IParserToolingV1).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice Parses only the pragma section of Rainlang source `data`. Returns the
    /// list of sub-parsers declared by the pragma.
    /// @param data The Rainlang source bytes to parse the pragma from.
    /// @return The pragma containing declared sub-parsers.
    function parsePragma1(bytes memory data) external view virtual checkParseMemoryOverflow returns (PragmaV1 memory) {
        ParseState memory parseState = LibParseState.newState(
            data, parseMeta(), operandHandlerFunctionPointers(), literalParserFunctionPointers()
        );
        uint256 cursor = Pointer.unwrap(data.dataPointer());
        uint256 end = Pointer.unwrap(data.endDataPointer());
        cursor = parseState.parseInterstitial(cursor, end);
        cursor = parseState.parsePragma(cursor, end);
        (cursor);
        return PragmaV1(parseState.exportSubParsers());
    }

    /// @notice Virtual function to return the parse meta.
    /// @return The parse meta bytes.
    function parseMeta() internal pure virtual returns (bytes memory) {
        return PARSE_META;
    }

    /// @notice Virtual function to return the operand handler function
    /// pointers.
    /// @return The packed operand handler function pointers.
    function operandHandlerFunctionPointers() internal pure virtual returns (bytes memory) {
        return OPERAND_HANDLER_FUNCTION_POINTERS;
    }

    /// @notice Virtual function to return the literal parser function
    /// pointers.
    /// @return The packed literal parser function pointers.
    function literalParserFunctionPointers() internal pure virtual returns (bytes memory) {
        return LITERAL_PARSER_FUNCTION_POINTERS;
    }

    /// @inheritdoc IParserToolingV1
    function buildOperandHandlerFunctionPointers() external pure override returns (bytes memory) {
        return LibAllStandardOps.operandHandlerFunctionPointers();
    }

    /// @inheritdoc IParserToolingV1
    function buildLiteralParserFunctionPointers() external pure override returns (bytes memory) {
        return LibAllStandardOps.literalParserFunctionPointers();
    }
}
