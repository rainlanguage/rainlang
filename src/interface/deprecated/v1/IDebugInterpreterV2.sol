// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

import {IInterpreterStoreV1, FullyQualifiedNamespace} from "./IInterpreterStoreV1.sol";
// Exported for convenience.
//forge-lint: disable-next-line(unused-import)
import {IInterpreterV1, SourceIndex} from "./IInterpreterV1.sol";

interface IDebugInterpreterV2 {
    /// A more explicit/open version of `eval` that is designed for offchain
    /// debugging. It MUST function identically to `eval` so implementations
    /// MAY call it directly internally for `eval` to ensure consistency at the
    /// expense of a small amount of gas.
    /// The affordances made for debugging are:
    /// - A fully qualified namespace is passed in. This allows for storage reads
    ///   from the perspective of an arbitrary caller during `eval`. Note that it
    ///   does not allow for arbitrary writes, which are still gated by the store
    ///   contract itself, so this is safe to expose.
    /// - The bytecode is passed in directly. This allows for debugging of
    ///   bytecode that has not been deployed to the chain yet.
    /// - The components of the encoded dispatch other than the onchain
    ///   expression address are passed separately. This remove the need to
    ///   provide an address at all.
    /// - Inputs to the entrypoint stack are passed in directly. This allows for
    ///   debugging/simulating logic that could normally only be accessed via.
    ///   some internal dispatch with a mid-flight state creating inputs for the
    ///   internal call.
    function offchainDebugEval(
        IInterpreterStoreV1 store,
        FullyQualifiedNamespace namespace,
        bytes calldata expressionData,
        SourceIndex sourceIndex,
        uint256 maxOutputs,
        uint256[][] calldata context,
        uint256[] calldata inputs
    ) external view returns (uint256[] calldata finalStack, uint256[] calldata writes);
}
