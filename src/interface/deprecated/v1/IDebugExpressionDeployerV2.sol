// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

interface IDebugExpressionDeployerV2 {
    /// Drives an integrity check of the provided bytecode and constants.
    /// Unlike `IDebugExpressionDeployerV1` this version ONLY checks the
    /// integrity of bytecode as produced by `IParserV1.parse`. There is an eval
    /// debug method on `IDebugInterpreterV2` that can be used to check the
    /// runtime outputs of bytecode that passes the integrity check.
    /// Integrity check MUST revert with a descriptive error if the bytecode
    /// fails the integrity check.
    /// @param bytecode The bytecode to check.
    /// @param constants The constants to check.
    /// @param minOutputs The minimum number of outputs expected from each of
    /// the sources. Only applies to sources that are entrypoints. Internal
    /// sources have their integrity checked implicitly by the use of opcodes
    /// such as `call` that have min/max outputs in their operand.
    function integrityCheck(bytes calldata bytecode, uint256[] calldata constants, uint256[] calldata minOutputs)
        external
        view;
}
