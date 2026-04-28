// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {LibInterpreterDeploy} from "../lib/deploy/LibInterpreterDeploy.sol";
import {IRainlang} from "../interface/IRainlang.sol";
import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";

/// @title Rainlang
/// @notice Rainlang contract that exposes the deterministic Zoltu deploy
/// addresses of the four core interpreter components: Deployer, Interpreter,
/// Store, and Parser. Deployed via the same Zoltu pattern so that external
/// tooling can discover all component addresses from a single known Rainlang
/// address.
contract Rainlang is IRainlang, ERC165 {
    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IRainlang).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IRainlang
    function expressionDeployerAddress() external pure virtual override returns (address) {
        return LibInterpreterDeploy.EXPRESSION_DEPLOYER_DEPLOYED_ADDRESS;
    }

    /// @inheritdoc IRainlang
    function interpreterAddress() external pure virtual override returns (address) {
        return LibInterpreterDeploy.INTERPRETER_DEPLOYED_ADDRESS;
    }

    /// @inheritdoc IRainlang
    function storeAddress() external pure virtual override returns (address) {
        return LibInterpreterDeploy.STORE_DEPLOYED_ADDRESS;
    }

    /// @inheritdoc IRainlang
    function parserAddress() external pure virtual override returns (address) {
        return LibInterpreterDeploy.PARSER_DEPLOYED_ADDRESS;
    }
}
