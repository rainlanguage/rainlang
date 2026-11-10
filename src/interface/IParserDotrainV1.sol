// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

/// A `-b name=value` binding as passed to `rain dotrain compose`.
/// @param name The dotrain binding name to rebind.
/// @param value The value, rendered as a 64 digit hex literal.
struct DotrainBinding {
    string name;
    bytes32 value;
}

/// @title IParserDotrainV1
/// @notice Interface for compiling one entrypoint of a dotrain into
/// interpreter bytecode.
interface IParserDotrainV1 {
    /// Composes `entrypoint` of `dotrain` with `bindings` as
    /// `rain dotrain compose` does, then parses the result as `parse2` does.
    /// MUST revert if the dotrain cannot be composed or the result is not
    /// valid Rainlang.
    /// @param dotrain The dotrain source.
    /// @param entrypoint The expression binding to compose.
    /// @param bindings Values for the dotrain's literal or elided bindings.
    /// @return bytecode The compiled bytecode ready for evaluation.
    function parseDotrain2(string calldata dotrain, string calldata entrypoint, DotrainBinding[] calldata bindings)
        external
        view
        returns (bytes calldata bytecode);
}
