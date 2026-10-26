// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {IRainlangV2} from "../interface/IRainlangV2.sol";
import {ERC165} from "@openzeppelin-contracts-5.7.0/utils/introspection/ERC165.sol";

/// @title BaseRainlang
/// @notice Rainlang contract that exposes the addresses of the four core
/// interpreter components: Compiler, Interpreter, Store, and Parser, so that
/// external tooling can discover all component addresses from a single known
/// Rainlang address. The addresses themselves are the `IRainlangV2` functions,
/// which a concrete binds.
abstract contract BaseRainlang is IRainlangV2, ERC165 {
    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IRainlangV2).interfaceId || super.supportsInterface(interfaceId);
    }
}
