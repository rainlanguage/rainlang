// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

import {StackItem} from "./IInterpreterV4.sol";

type EncodedExternDispatchV2 is bytes32;

type ExternDispatchV2 is bytes32;

/// @title IInterpreterExternV4
/// Handle a single dispatch from some calling contract with an array of
/// inputs and array of outputs. Ostensibly useful to build "word packs" for
/// `IInterpreterV4` so that less frequently used words can be provided in
/// a less efficient format, but without bloating the base interpreter in
/// terms of code size. Effectively allows unlimited words to exist as externs
/// alongside interpreters.
///
/// The difference between V3 and V4 is that V4 uses the `bytes32` type rather
/// than `uint256` for better binary/numeric clarity.
interface IInterpreterExternV4 {
    /// Checks the integrity of some extern call. Called during parsing/bytecode
    /// building, NOT at eval runtime.
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
    function externIntegrity(ExternDispatchV2 dispatch, uint256 expectedInputs, uint256 expectedOutputs)
        external
        view
        returns (uint256 actualInputs, uint256 actualOutputs);

    /// Handles a single dispatch.
    /// @param dispatch Encoded information about the extern to dispatch.
    /// Analogous to the opcode/operand in the interpreter.
    /// @param inputs The array of inputs for the dispatched logic.
    /// @return outputs The result of the dispatched logic.
    function extern(ExternDispatchV2 dispatch, StackItem[] calldata inputs)
        external
        view
        returns (StackItem[] calldata outputs);
}
