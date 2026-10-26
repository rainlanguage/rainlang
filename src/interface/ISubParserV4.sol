// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

// Reexports for implementations to use.
//forge-lint: disable-next-line(unused-import)
import {AuthoringMetaV2} from "./deprecated/v2/ISubParserV3.sol";
//forge-lint: disable-next-line(unused-import)
import {OperandV2} from "./IInterpreterV4.sol";

/// @title ISubParserV4
/// Identical to `ISubParserV3` except the interface functions are versioned
/// rather than using compatibility versions.
///
/// The data layout is identical to `COMPATIBILITY_V5` from `ISubParserV3`,
/// except that parsed values are `bytes32` to better represent that they are NOT
/// expected to be used as integers (most likely packed float values).
interface ISubParserV4 {
    /// The sub parser is being asked to attempt to parse a literal that the main
    /// parser has failed to parse. It is expected that the main parser will
    /// attempt multiple sub parsers in order to parse a literal, so the sub
    /// parser MUST NOT revert if it does not know how to parse the literal, as
    /// some other sub parser may be able to parse it. The sub parser MUST return
    /// false if it does not know how to parse the literal, and MUST return true
    /// if it does know how to parse the literal, as well as the value of the
    /// literal.
    ///
    /// If the sub parser knows how to parse some literal, but the data is
    /// malformed, the sub parser MUST revert.
    ///
    /// Literal parsing is the process of taking a sequence of bytes and
    /// converting it into a value that is known at compile time.
    ///
    /// @param data The data that represents the literal. The structure of this
    /// is defined by the conventions for the compatibility version.
    /// @return success Whether the sub parser knows how to parse the literal.
    /// If the sub parser does know how to handle the literal but cannot due to
    /// malformed data, or some other reason, it MUST revert.
    /// @return value The value of the literal.
    function subParseLiteral2(bytes calldata data) external view returns (bool success, bytes32 value);

    /// The sub parser is being asked to attempt to parse a word that the main
    /// parser has failed to parse. It is expected that the main parser will
    /// attempt multiple sub parsers in order to parse a word, so the sub parser
    /// MUST NOT revert if it does not know how to parse the word, as some other
    /// sub parser may be able to parse it. The sub parser MUST return false if
    /// it does not know how to parse the word, and MUST return true if it does
    /// know how to parse the word, as well as the bytecode and constants of the
    /// word.
    ///
    /// If the sub parser knows how to parse some word, but the data is
    /// malformed, the sub parser MUST revert.
    ///
    /// Word parsing is the process of taking a sequence of bytes and
    /// converting it into a sequence of bytecode and constants that is known at
    /// compile time, and will be executed at runtime. As the bytecode executes
    /// on the interpreter, not the (sub)parser, the sub parser relies on
    /// convention to ensure that it is producing valid bytecode and constants.
    ///
    /// @param data The data that represents the word.
    /// @return success Whether the sub parser knows how to parse the word.
    /// If the sub parser does know how to handle the word but cannot due to
    /// malformed data, or some other reason, it MUST revert.
    /// @return bytecode The bytecode of the word.
    /// @return constants The constants of the word. This MAY be empty if the
    /// bytecode does not require any new constants. These constants will be
    /// merged into the constants of the main parser.
    function subParseWord2(bytes calldata data)
        external
        view
        returns (bool success, bytes memory bytecode, bytes32[] memory constants);
}
