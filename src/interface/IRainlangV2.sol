// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @title IRainlangV2
/// @notice Interface for Rainlang that exposes the deterministic deploy
/// addresses of the four core interpreter components (Compiler, Interpreter,
/// Store, Parser).
interface IRainlangV2 {
    /// @notice Returns the deterministic deploy address of the compiler.
    /// @return The compiler address.
    function compilerAddress() external pure returns (address);

    /// @notice Returns the deterministic deploy address of the interpreter.
    /// @return The interpreter address.
    function interpreterAddress() external pure returns (address);

    /// @notice Returns the deterministic deploy address of the store.
    /// @return The store address.
    function storeAddress() external pure returns (address);

    /// @notice Returns the deterministic deploy address of the parser.
    /// @return The parser address.
    function parserAddress() external pure returns (address);
}
