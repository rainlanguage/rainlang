// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {BaseRainlangExtern} from "../../../src/abstract/BaseRainlangExtern.sol";

/// @dev We need a contract that is deployable in order to test the abstract
/// base contract. Must override the function pointer virtuals to return
/// non-empty, equal-length bytes so the constructor validation passes.
contract ChildRainlangExtern is BaseRainlangExtern {
    function opcodeFunctionPointers() internal pure override returns (bytes memory) {
        return hex"0000";
    }

    function integrityFunctionPointers() internal pure override returns (bytes memory) {
        return hex"0000";
    }

    function buildIntegrityFunctionPointers() external pure returns (bytes memory) {
        return integrityFunctionPointers();
    }

    function buildOpcodeFunctionPointers() external pure returns (bytes memory) {
        return opcodeFunctionPointers();
    }
}
