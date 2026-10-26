// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

// Reexports for implementations to use.
//forge-lint: disable-next-line(unused-import)
import {AuthoringMetaV2} from "../v1/IParserV1.sol";
// Exported for convenience.
//forge-lint: disable-next-line(unused-import)
import {Operand} from "../v1/IInterpreterV2.sol";
// Exported for convenience.
//forge-lint: disable-next-line(unused-import)
import {COMPATIBILITY_V2, COMPATIBILITY_V3, COMPATIBILITY_V4} from "../v1/ISubParserV2.sol";

/// @dev A compatibility version for the subparser interface.
///
/// Identical to COMPATIBILITY_V4, except that instead of all decimal values
/// being scaled to an 18 decimal fixed point, decimal values are now all
/// packed floating point values as per the canonical Rain implementation.
///
/// This implies that only hex literals can represent binary integer values.
///
/// This also implies that negative numbers are valid, and values that are far
/// out of range of fixed point representations.
bytes32 constant COMPATIBILITY_V5 = keccak256("2024.08.25 Rainlang ISubParserV3");

/// @title ISubParserV3
/// Identical to `ISubParserV2` except the interface is `view` instead of `pure`.
interface ISubParserV3 {
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
        view
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
        view
        returns (bool success, bytes memory bytecode, uint256[] memory constants);
}
