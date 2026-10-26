// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

// Reexports for implementations to use.
// Exported for convenience.
//forge-lint: disable-next-line(unused-import)
import {AuthoringMetaV2} from "./IParserV1.sol";
// Exported for convenience.
//forge-lint: disable-next-line(unused-import)
import {Operand} from "./IInterpreterV2.sol";

/// @dev A compatibility version for the subparser interface.
///
/// ## Literal parsing
///
/// The structure of data for this version is:
/// - bytes [0,1]: The length of the dispatch data as 2 bytes.
/// - bytes [2,N-1+2]: The dispatch data, where N is the length of the dispatch
///   data as defined by the first 2 bytes. This is used by the sub parser to
///   decide which literal parser to use. If there are no matches the sub parser
///   MUST return false and MUST NOT revert.
/// - bytes [N+2,...]: The literal data that the sub parser is being asked to
///   parse. The sub parser MUST revert if it cannot parse the literal, once it
///   has determined that it is the correct sub parser to handle the literal.
///
/// ## Word parsing
///
/// The structure of data for this version is:
/// - bytes [0,1]: The current height of the constants array on the main parser.
/// - bytes [2,2]: The IO byte, that at the time of writing represents the
///   number of inputs to the word.
/// - bytes [3,4]; Two bytes that encodes N where N is the length in bytes of the
///   rainlang word that could not be parsed in bytes.
/// - bytes [5, N+5]: A string slice that the parser could not parse. For well
///   formed rainlang it will be a word WITHOUT any associated operands. The
///   parsing of operands is handled by the main parser, and the subparser is
///   only expected to parse the word itself and handle the pre-parsed operand
///   values.
/// - bytes [N+5,...]: The operands that the main parser has already parsed as
///   a standard `uint256[]` array. The subparser is expected to handle these
///   operands as-is, and return bytecode that is compatible with the operand
///   values. The first word of the array is the array length.
bytes32 constant COMPATIBILITY_V2 = keccak256("2023.12.28 Rainlang ISubParserV2");

/// @dev A compatibility version for the subparser interface.
///
/// Identical to COMPATIBILITY_V2, except the IO byte in word parsing now encodes
/// both the inputs and outputs. The IO byte is [2,2] in the word parsing data.
/// The high/leftmost 4 bits of the IO byte encode the number of outputs, and the
/// low/rightmost 4 bits of the IO byte encode the number of inputs. This implies
/// that the number of inputs and outputs must each be less than 16.
bytes32 constant COMPATIBILITY_V3 = keccak256("2024.02.15 Rainlang ISubParserV3");

/// @dev A compatibility version for the subparser interface.
///
/// Identical to COMPATIBLITY_V3, except the main parser now scales decimal
/// literals to 18 fixed point decimals unconditionally. Other literals such as
/// hex are unmodified by this change.
///
/// Values that are intended to be used as fixed point decimals are unaffected
/// because the main parser is now simply better at parsing them.
///
/// Values that are intended to be used as integers, such as `1`, need to
/// consider that the original literal may have parsed to
/// e.g. either `1` or `1e18` as the user may have written `1` or `0x01` into the
/// parsed source respectively.
///
/// Subparsers should be aware of this change and treat exact multiples of
/// `1e18` as integers if and when it makes sense to.
bytes32 constant COMPATIBILITY_V4 = keccak256("2024.05.9 Rainlang ISubParserV2");

interface ISubParserV2 {
    /// The sub parser is being asked to attempt to parse a literal that the main
    /// parser has failed to parse. The sub parser MUST ONLY attempt to parse a
    /// literal that matches both the compatibility version and that the data
    /// represents a literal that the sub parser is capable of parsing. It is
    /// expected that the main parser will attempt multiple sub parsers in order
    /// to parse a literal, so the sub parser MUST NOT revert if it does not know
    /// how to parse the literal, as some other sub parser may be able to parse
    /// it. The sub parser MUST return false if it does not know how to parse the
    /// literal, and MUST return true if it does know how to parse the literal,
    /// as well as the value of the literal.
    /// If the sub parser knows how to parse some literal, but the data is
    /// malformed, the sub parser MUST revert.
    /// If the compatibility version is not supported, the sub parser MUST
    /// revert.
    ///
    /// Literal parsing is the process of taking a sequence of bytes and
    /// converting it into a value that is known at compile time.
    ///
    /// @param compatibility The compatibility version of the parser that the
    /// sub parser must support in order to parse the literal.
    /// @param data The data that represents the literal. The structure of this
    /// is defined by the conventions for the compatibility version.
    /// @return success Whether the sub parser knows how to parse the literal.
    /// If the sub parser does know how to handle the literal but cannot due to
    /// malformed data, or some other reason, it MUST revert.
    /// @return value The value of the literal.
    function subParseLiteral(bytes32 compatibility, bytes calldata data)
        external
        pure
        returns (bool success, uint256 value);

    /// The sub parser is being asked to attempt to parse a word that the main
    /// parser has failed to parse. The sub parser MUST ONLY attempt to parse a
    /// word that matches both the compatibility version and that the data
    /// represents a word that the sub parser is capable of parsing. It is
    /// expected that the main parser will attempt multiple sub parsers in order
    /// to parse a word, so the sub parser MUST NOT revert if it does not know
    /// how to parse the word, as some other sub parser may be able to parse
    /// it. The sub parser MUST return false if it does not know how to parse the
    /// word, and MUST return true if it does know how to parse the word,
    /// as well as the bytecode and constants of the word.
    /// If the sub parser knows how to parse some word, but the data is
    /// malformed, the sub parser MUST revert.
    ///
    /// Word parsing is the process of taking a sequence of bytes and
    /// converting it into a sequence of bytecode and constants that is known at
    /// compile time, and will be executed at runtime. As the bytecode executes
    /// on the interpreter, not the (sub)parser, the sub parser relies on
    /// convention to ensure that it is producing valid bytecode and constants.
    /// These conventions are defined by the compatibility versions.
    ///
    /// @param compatibility The compatibility version of the parser that the
    /// sub parser must support in order to parse the word.
    /// @param data The data that represents the word.
    /// @return success Whether the sub parser knows how to parse the word.
    /// If the sub parser does know how to handle the word but cannot due to
    /// malformed data, or some other reason, it MUST revert.
    /// @return bytecode The bytecode of the word.
    /// @return constants The constants of the word. This MAY be empty if the
    /// bytecode does not require any new constants. These constants will be
    /// merged into the constants of the main parser.
    function subParseWord(bytes32 compatibility, bytes calldata data)
        external
        pure
        returns (bool success, bytes memory bytecode, uint256[] memory constants);
}
