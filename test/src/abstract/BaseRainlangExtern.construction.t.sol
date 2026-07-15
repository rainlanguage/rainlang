// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {BaseRainlangExtern} from "../../../src/abstract/BaseRainlangExtern.sol";
import {ExternPointersMismatch, ExternOpcodePointersEmpty} from "../../../src/error/ErrExtern.sol";
import {EmptyPointersExtern} from "./EmptyPointersExtern.sol";
import {MismatchedExternMoreOpcodes} from "./MismatchedExternMoreOpcodes.sol";
import {MismatchedExternMoreIntegrity} from "./MismatchedExternMoreIntegrity.sol";

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
