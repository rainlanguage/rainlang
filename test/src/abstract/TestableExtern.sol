// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {BaseRainlangExtern} from "../../../src/abstract/BaseRainlangExtern.sol";
import {ExternPointersMismatch, ExternOpcodePointersEmpty} from "../../../src/error/ErrExtern.sol";

/// @dev Shared base that exposes the internal pointer functions externally.
abstract contract TestableExtern is BaseRainlangExtern {
    function buildIntegrityFunctionPointers() external pure returns (bytes memory) {
        return integrityFunctionPointers();
    }

    function buildOpcodeFunctionPointers() external view returns (bytes memory) {
        return opcodeFunctionPointers();
    }
}
