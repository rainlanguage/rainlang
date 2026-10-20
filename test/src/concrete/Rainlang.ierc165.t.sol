// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";

import {IERC165} from "@openzeppelin-contracts-5.7.0/utils/introspection/IERC165.sol";
import {TestRainlang} from "test/concrete/TestRainlang.sol";
import {IRainlang} from "../../../src/interface/IRainlang.sol";

/// @title RainlangIERC165Test
/// @notice Test that ERC165 is implemented for Rainlang.
contract RainlangIERC165Test is Test {
    /// Test that ERC165 is implemented for all interfaces.
    function testRainlangIERC165(bytes4 badInterfaceId) external {
        vm.assume(badInterfaceId != type(IERC165).interfaceId);
        vm.assume(badInterfaceId != type(IRainlang).interfaceId);

        TestRainlang rainlang = new TestRainlang();
        assertTrue(rainlang.supportsInterface(type(IERC165).interfaceId));
        assertTrue(rainlang.supportsInterface(type(IRainlang).interfaceId));

        assertFalse(rainlang.supportsInterface(badInterfaceId));
    }
}
