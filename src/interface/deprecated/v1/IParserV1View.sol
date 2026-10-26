// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

// Exported for convenience.
//forge-lint: disable-next-line(unused-import)
import {AuthoringMeta, AuthoringMetaV2} from "./IParserV1.sol";

/// @title IParserV1View
/// Identical to `IParserV1` except the interface is `view` instead of `pure`.
interface IParserV1View {
    /// Parses a Rainlang string into an evaluable expression. MUST be
    /// deterministic and MUST NOT have side effects. The only inputs are the
    /// Rainlang string and the parse meta. MAY revert if the Rainlang string
    /// is invalid. This function takes `bytes` instead of `string` to allow
    /// for definitions of "string" other than UTF-8.
    /// @param data The Rainlang bytes to parse.
    /// @return bytecode The expressions that can be evaluated.
    /// @return constants The constants that can be referenced by sources.
    function parse(bytes calldata data) external view returns (bytes calldata bytecode, uint256[] calldata constants);
}
