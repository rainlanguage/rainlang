// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {IRainlang} from "../interface/IRainlang.sol";
import {ERC165} from "@openzeppelin-contracts-5.7.0/utils/introspection/ERC165.sol";

/// @title BaseRainlang
/// @notice Rainlang contract that exposes the addresses of the four core
/// interpreter components: Deployer, Interpreter, Store, and Parser, so that
/// external tooling can discover all component addresses from a single known
/// Rainlang address. The addresses themselves are the `IRainlang` functions,
/// which a concrete binds.
abstract contract BaseRainlang is IRainlang, ERC165 {
    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IRainlang).interfaceId || super.supportsInterface(interfaceId);
    }
}
