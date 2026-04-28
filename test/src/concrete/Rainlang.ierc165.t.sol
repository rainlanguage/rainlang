// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {Rainlang} from "../../../src/concrete/Rainlang.sol";
import {IRainlang} from "../../../src/interface/IRainlang.sol";

/// @title RainlangIERC165Test
/// @notice Test that ERC165 is implemented for Rainlang.
contract RainlangIERC165Test is Test {
    /// Test that ERC165 is implemented for all interfaces.
    function testRainlangIERC165(bytes4 badInterfaceId) external {
        vm.assume(badInterfaceId != type(IERC165).interfaceId);
        vm.assume(badInterfaceId != type(IRainlang).interfaceId);

        Rainlang rainlang = new Rainlang();
        assertTrue(rainlang.supportsInterface(type(IERC165).interfaceId));
        assertTrue(rainlang.supportsInterface(type(IRainlang).interfaceId));

        assertFalse(rainlang.supportsInterface(badInterfaceId));
    }
}
