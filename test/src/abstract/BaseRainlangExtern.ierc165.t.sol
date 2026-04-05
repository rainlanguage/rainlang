// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {IInterpreterExternV4} from "rain.interpreter.interface/interface/IInterpreterExternV4.sol";
import {BaseRainlangExtern} from "../../../src/abstract/BaseRainlangExtern.sol";
import {IIntegrityToolingV1} from "rain.sol.codegen/interface/IIntegrityToolingV1.sol";
import {IOpcodeToolingV1} from "rain.sol.codegen/interface/IOpcodeToolingV1.sol";

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

/// @title BaseRainlangExternTest
/// @notice Test suite for BaseRainlangExtern.
contract BaseRainlangExternIERC165Test is Test {
    /// Test that ERC165 and IInterpreterExternV4 are supported interfaces as
    /// per ERC165.
    function testRainlangExternIERC165(bytes4 badInterfaceId) external {
        vm.assume(badInterfaceId != type(IERC165).interfaceId);
        vm.assume(badInterfaceId != type(IInterpreterExternV4).interfaceId);
        vm.assume(badInterfaceId != type(IIntegrityToolingV1).interfaceId);
        vm.assume(badInterfaceId != type(IOpcodeToolingV1).interfaceId);

        ChildRainlangExtern extern = new ChildRainlangExtern();
        assertTrue(extern.supportsInterface(type(IERC165).interfaceId));
        assertTrue(extern.supportsInterface(type(IInterpreterExternV4).interfaceId));
        assertTrue(extern.supportsInterface(type(IIntegrityToolingV1).interfaceId));
        assertTrue(extern.supportsInterface(type(IOpcodeToolingV1).interfaceId));
        assertFalse(extern.supportsInterface(badInterfaceId));
    }
}
