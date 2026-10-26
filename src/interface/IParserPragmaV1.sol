// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

/// @dev Pragma configuration for a parser.
/// @param usingWordsFrom Addresses of sub-parser contracts whose words should
/// be available during parsing. Implementations SHOULD validate entries
/// (reject zero addresses, handle duplicates).
struct PragmaV1 {
    address[] usingWordsFrom;
}

/// @title IParserPragmaV1
/// @notice Interface for extracting pragma directives from Rainlang source.
interface IParserPragmaV1 {
    /// Parses pragma directives from Rainlang source data.
    /// @param data The Rainlang source to extract pragmas from.
    /// @return The parsed pragma containing any `usingWordsFrom` addresses.
    function parsePragma1(bytes calldata data) external view returns (PragmaV1 calldata);
}
