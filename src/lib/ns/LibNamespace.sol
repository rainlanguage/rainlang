// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {StateNamespace, FullyQualifiedNamespace} from "../../interface/IInterpreterV4.sol";

/// @title LibNamespace
/// @notice Conventions for working with namespaces as a calling contract. All of
/// this functionality is OPTIONAL but probably useful for the majority of
/// contracts as it enables safe (scoped) mutations in Rainlang.
library LibNamespace {
    /// Standard way to elevate a caller-provided state namespace to a universal
    /// namespace that is disjoint from all other caller-provided namespaces.
    /// Essentially just hashes the `msg.sender` into the state namespace as-is.
    ///
    /// This is deterministic such that the same combination of state namespace
    /// and caller will produce the same fully qualified namespace, even across
    /// multiple transactions/blocks.
    ///
    /// @param stateNamespace The state namespace as specified by the caller.
    /// @param sender The caller this namespace is bound to.
    /// @return qualifiedNamespace A fully qualified namespace that cannot
    /// collide with any other state namespace specified by any other caller.
    function qualifyNamespace(StateNamespace stateNamespace, address sender)
        internal
        pure
        returns (FullyQualifiedNamespace qualifiedNamespace)
    {
        assembly ("memory-safe") {
            mstore(0, stateNamespace)
            mstore(0x20, sender)
            qualifiedNamespace := keccak256(0, 0x40)
        }
    }
}
