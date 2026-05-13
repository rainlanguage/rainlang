// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {IERC165} from "@openzeppelin-contracts-5.6.1/utils/introspection/IERC165.sol";
import {RainlangStore} from "../../../src/concrete/RainlangStore.sol";
import {IInterpreterStoreV3} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterStoreV3.sol";

contract RainlangStoreIERC165Test is Test {
    /// Store should introspect support for `IERC165` and `IInterpreterStoreV3`.
    /// It should not support any other interface.
    function testRainlangStoreIERC165(bytes4 badInterfaceId) external {
        vm.assume(badInterfaceId != type(IERC165).interfaceId);
        vm.assume(badInterfaceId != type(IInterpreterStoreV3).interfaceId);

        RainlangStore store = new RainlangStore();
        assertTrue(store.supportsInterface(type(IERC165).interfaceId));
        assertTrue(store.supportsInterface(type(IInterpreterStoreV3).interfaceId));

        assertFalse(store.supportsInterface(badInterfaceId));
    }
}
