// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

/// @dev This is the first compatibility version of the subparser interface.
/// Likely it won't survive long, but it's here to demonstrate the concept.
/// The structure of data for this version is:
/// - bytes [0,1]: The current height of the constants array on the main parser.
/// - bytes [2,2]: The IO byte, that at the time of writing represents the
///   number of inputs to the word.
/// - bytes [3, .. ]: A string slice that the parser could not parse. For well
///   formed rainlang it will be a word and any associated operands, from the
///   first word char to the char before the opening `(` paren.
bytes32 constant COMPATIBLITY_V0 = keccak256("2023.12.17 Rainlang Parser v0");

/// @dev This is the second compatibility version of the subparser interface.
/// Likely it won't survive long, but it's here to demonstrate the concept.
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
bytes32 constant COMPATIBLITY_V1 = keccak256("2023.12.26 Rainlang Parser v1");

interface ISubParserV1 {
    /// Handle parsing some data on behalf of a parser. The structure and meaning
    /// of the data is entirely up to the parser, the compatibility version
    /// indicates a unique ID for a particular parseble data convention.
    ///
    /// @param compatibility The compatibility version of the data to parse. The
    /// sub parser is free to handle this however it likes, but it MUST revert if
    /// it is unsure how to handle the data. E.g. the sub parser MAY revert any
    /// compatibility version that is not an exact match to a singular known
    /// constant, or it may attempt to support several versions.
    ///
    /// @param data The data to parse. The main parser will provide arbitrary
    /// data that is expected to match the conventions implied by the
    /// compatibility version. As sub parsing is a read only operation, any
    /// corrupt data could only possibly harm the main parser, which in turn
    /// should be parsing as a read only operation to protect itself from
    /// malicious inputs.
    ///
    /// @return success The first return value is a success flag, yet the sub
    /// parser MAY REVERT under certain conditions. It is important to know when
    /// to revert and when to return false. The general rule is that if the
    /// inputs are understood by the subparser, and look wrong to the subparser,
    /// then the subparser MUST revert. If the inputs are not understood by the
    /// subparser, it MUST NOT revert, as it is not in a position to know if the
    /// inputs are wrong or not, and there is very likely some other subparser
    /// known to the main parser that can handle the data as a fallback.
    ///
    /// For example, the following situations are expected to revert:
    /// - The compatibility ID is not supported by the sub parser. Every sub
    ///   parser knows what it is compatible with, so it is safe to revert
    ///   anything incompatible.
    /// - The data parses to something the sub parser knows how to handle, but
    ///   the data is malformed in some way. For example, the sub parser knows
    ///   the word it is parsing, but perhaps some associated data such as the
    ///   constants height is out of a valid range.
    ///
    /// Similarly, the following situations are expected to return false and not
    /// revert:
    /// - The compatibility ID is supported by the sub parser, and the data
    ///   appears to have the correct structure, but there are no recognized
    ///   words in the data. This MUST NOT revert, as some other sub parser MAY
    ///   recognize the word and handle it as a fallback.
    ///
    /// @return bytecode If successful, the second return value is the bytecode
    /// that the subparser has generated. The main parser is expected to merge
    /// this into the main bytecode as-is, so it MUST match main parser
    /// behaviour as per the compatibility conventions. If unsuccessful, a zero
    /// length byte array.
    ///
    /// @return constants If successful, and the generated bytecode implies
    /// additions to the constants array, the third return value is the
    /// constants that the subparser has generated. The main parser is expected
    /// to merge this into the main constants array as-is. If the parsing is
    /// unsuccessful, or the generated bytecode does not require any new
    /// constants, a zero length array.
    function subParse(bytes32 compatibility, bytes calldata data)
        external
        pure
        returns (bool success, bytes calldata bytecode, uint256[] calldata constants);
}
