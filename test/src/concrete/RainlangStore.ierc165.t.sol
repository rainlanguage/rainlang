// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";

import {IERC165} from "@openzeppelin-contracts-5.6.1/utils/introspection/IERC165.sol";
import {TestRainlangStore} from "test/concrete/TestRainlangStore.sol";
import {IInterpreterStoreV3} from "rainlang-interface-0.2.9/src/interface/IInterpreterStoreV3.sol";

contract RainlangStoreIERC165Test is Test {
    /// Store should introspect support for `IERC165` and `IInterpreterStoreV3`.
    /// It should not support any other interface.
    function testRainlangStoreIERC165(bytes4 badInterfaceId) external {
        vm.assume(badInterfaceId != type(IERC165).interfaceId);
        vm.assume(badInterfaceId != type(IInterpreterStoreV3).interfaceId);

        TestRainlangStore store = new TestRainlangStore();
        assertTrue(store.supportsInterface(type(IERC165).interfaceId));
        assertTrue(store.supportsInterface(type(IInterpreterStoreV3).interfaceId));

        assertFalse(store.supportsInterface(badInterfaceId));
    }
}
