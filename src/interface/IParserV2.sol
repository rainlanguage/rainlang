// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

// Reexport AuthoringMetaV2 for downstream use.
//forge-lint: disable-next-line(unused-import)
import {AuthoringMetaV2} from "./deprecated/v1/IParserV1.sol";

/// @title IParserV2
/// @notice Interface for parsing Rainlang source into interpreter bytecode.
interface IParserV2 {
    /// Parses Rainlang source data into bytecode compatible with
    /// `IInterpreterV4.eval4`. MUST revert if the input is not valid Rainlang.
    /// @param data The Rainlang source to parse.
    /// @return bytecode The compiled bytecode ready for evaluation.
    function parse2(bytes calldata data) external view returns (bytes calldata bytecode);
}
