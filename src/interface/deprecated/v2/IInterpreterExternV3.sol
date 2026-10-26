// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

// Exported for convenience.
//forge-lint: disable-next-line(unused-import)
import {EncodedExternDispatch, ExternDispatch} from "../v1/IInterpreterExternV2.sol";

/// @title IInterpreterExternV3
/// Handle a single dispatch from some calling contract with an array of
/// inputs and array of outputs. Ostensibly useful to build "word packs" for
/// `IInterpreterV2` so that less frequently used words can be provided in
/// a less efficient format, but without bloating the base interpreter in
/// terms of code size. Effectively allows unlimited words to exist as externs
/// alongside interpreters.
///
/// The difference between V2 and V3 is that V3 integrates with integrity checks.
interface IInterpreterExternV3 {
    /// Checks the integrity of some extern call.
    /// @param dispatch Encoded information about the extern to dispatch.
    /// Analogous to the opcode/operand in the interpreter.
    /// @param expectedInputs The number of inputs expected for the dispatched
    /// logic.
    /// @param expectedOutputs The number of outputs expected for the dispatched
    /// logic.
    /// @return actualInputs The actual number of inputs for the dispatched
    /// logic.
    /// @return actualOutputs The actual number of outputs for the dispatched
    /// logic.
    function externIntegrity(ExternDispatch dispatch, uint256 expectedInputs, uint256 expectedOutputs)
        external
        view
        returns (uint256 actualInputs, uint256 actualOutputs);

    /// Handles a single dispatch.
    /// @param dispatch Encoded information about the extern to dispatch.
    /// Analogous to the opcode/operand in the interpreter.
    /// @param inputs The array of inputs for the dispatched logic.
    /// @return outputs The result of the dispatched logic.
    function extern(ExternDispatch dispatch, uint256[] calldata inputs)
        external
        view
        returns (uint256[] calldata outputs);
}
