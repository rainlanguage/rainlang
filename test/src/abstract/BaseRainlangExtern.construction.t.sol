// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
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

/// @dev Extern with empty opcode and integrity pointers.
contract EmptyPointersExtern is TestableExtern {
    function opcodeFunctionPointers() internal pure override returns (bytes memory) {
        return hex"";
    }

    function integrityFunctionPointers() internal pure override returns (bytes memory) {
        return hex"";
    }
}

/// @dev Extern with 2 opcode pointers but 1 integrity pointer.
contract MismatchedExternMoreOpcodes is TestableExtern {
    function opcodeFunctionPointers() internal pure override returns (bytes memory) {
        return hex"00010002";
    }

    function integrityFunctionPointers() internal pure override returns (bytes memory) {
        return hex"0001";
    }
}

/// @dev Extern with 1 opcode pointer but 2 integrity pointers.
contract MismatchedExternMoreIntegrity is TestableExtern {
    function opcodeFunctionPointers() internal pure override returns (bytes memory) {
        return hex"0001";
    }

    function integrityFunctionPointers() internal pure override returns (bytes memory) {
        return hex"00010002";
    }
}

/// @title BaseRainlangExternConstructionTest
/// @notice Tests construction invariants for BaseRainlangExtern.
contract BaseRainlangExternConstructionTest is Test {
    /// Construction reverts when opcode pointers outnumber integrity pointers.
    function testExternConstructorRevertsMoreOpcodes() external {
        vm.expectRevert(abi.encodeWithSelector(ExternPointersMismatch.selector, 4, 2));
        new MismatchedExternMoreOpcodes();
    }

    /// Construction reverts when integrity pointers outnumber opcode pointers.
    function testExternConstructorRevertsMoreIntegrity() external {
        vm.expectRevert(abi.encodeWithSelector(ExternPointersMismatch.selector, 2, 4));
        new MismatchedExternMoreIntegrity();
    }

    /// Construction reverts when opcode pointers are empty.
    function testExternConstructorRevertsEmptyPointers() external {
        vm.expectRevert(abi.encodeWithSelector(ExternOpcodePointersEmpty.selector));
        new EmptyPointersExtern();
    }
}
