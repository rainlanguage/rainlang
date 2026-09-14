// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ERC165} from "@openzeppelin-contracts-5.6.1/utils/introspection/ERC165.sol";

import {IInterpreterStoreV3} from "rainlang-interface-0.2.9/src/interface/IInterpreterStoreV3.sol";
import {
    LibNamespace,
    FullyQualifiedNamespace,
    StateNamespace
} from "rainlang-interface-0.2.9/src/lib/ns/LibNamespace.sol";
import {OddSetLength} from "../error/ErrStore.sol";

/// @title BaseRainlangStore
/// @notice Simplest possible `IInterpreterStoreV3` that could work.
/// Takes key/value pairings from the input array and stores each in an internal
/// mapping. `StateNamespace` is fully qualified only by `msg.sender` on set and
/// doesn't attempt to do any deduping etc. if the same key appears twice it will
/// be set twice.
abstract contract BaseRainlangStore is IInterpreterStoreV3, ERC165 {
    using LibNamespace for StateNamespace;

    /// Store is several tiers of sandbox.
    ///
    /// 0. Address hashed into `FullyQualifiedNamespace` is `msg.sender` so that
    ///    callers cannot attack each other
    /// 1. StateNamespace is caller-provided namespace so that expressions cannot
    ///    attack each other
    /// 2. `bytes32` is expression-provided key
    /// 3. `bytes32` is expression-provided value
    ///
    /// tiers 0 and 1 are both embodied in the `FullyQualifiedNamespace`.
    // Slither doesn't like the leading underscore.
    //solhint-disable-next-line private-vars-leading-underscore
    mapping(FullyQualifiedNamespace fullyQualifiedNamespace => mapping(bytes32 key => bytes32 value)) internal sStore;

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IInterpreterStoreV3).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IInterpreterStoreV3
    function set(StateNamespace namespace, bytes32[] calldata kvs) external virtual {
        // This would be picked up by an out of bounds index below, but it's
        // nice to have a more specific error message.
        if (kvs.length % 2 != 0) {
            revert OddSetLength(kvs.length);
        }
        unchecked {
            FullyQualifiedNamespace fullyQualifiedNamespace = namespace.qualifyNamespace(msg.sender);
            for (uint256 i = 0; i < kvs.length; i += 2) {
                bytes32 key = kvs[i];
                bytes32 value = kvs[i + 1];
                emit Set(fullyQualifiedNamespace, key, value);
                sStore[fullyQualifiedNamespace][key] = value;
            }
        }
    }

    /// @inheritdoc IInterpreterStoreV3
    function get(FullyQualifiedNamespace namespace, bytes32 key) external view virtual returns (bytes32) {
        return sStore[namespace][key];
    }
}
