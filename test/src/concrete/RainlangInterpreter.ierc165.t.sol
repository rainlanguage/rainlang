// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";

import {IERC165} from "@openzeppelin-contracts-5.6.1/utils/introspection/IERC165.sol";
import {TestRainlangInterpreter} from "test/concrete/TestRainlangInterpreter.sol";
import {IInterpreterV4} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {IOpcodeToolingV1} from "rain-sol-codegen-0.1.37/src/interface/IOpcodeToolingV1.sol";

contract RainlangInterpreterIERC165Test is Test {
    /// Test that ERC165 is implemented for all interfaces.
    function testRainlangInterpreterIERC165(bytes4 badInterfaceId) external {
        vm.assume(badInterfaceId != type(IERC165).interfaceId);
        vm.assume(badInterfaceId != type(IInterpreterV4).interfaceId);
        vm.assume(badInterfaceId != type(IOpcodeToolingV1).interfaceId);

        TestRainlangInterpreter interpreter = new TestRainlangInterpreter();
        assertTrue(interpreter.supportsInterface(type(IERC165).interfaceId));
        assertTrue(interpreter.supportsInterface(type(IInterpreterV4).interfaceId));
        assertTrue(interpreter.supportsInterface(type(IOpcodeToolingV1).interfaceId));

        assertFalse(interpreter.supportsInterface(badInterfaceId));
    }
}
