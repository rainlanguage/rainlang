// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";

import {IERC165} from "@openzeppelin-contracts-5.6.1/utils/introspection/IERC165.sol";
import {TestRainlangParser} from "test/concrete/TestRainlangParser.sol";
import {IParserToolingV1} from "rain-sol-codegen-0.1.37/src/interface/IParserToolingV1.sol";

contract RainlangParserIERC165Test is Test {
    /// Test that ERC165 is implemented for all interfaces.
    function testRainlangParserIERC165(bytes4 badInterfaceId) external {
        vm.assume(badInterfaceId != type(IERC165).interfaceId);
        vm.assume(badInterfaceId != type(IParserToolingV1).interfaceId);

        TestRainlangParser parser = new TestRainlangParser();
        assertTrue(parser.supportsInterface(type(IERC165).interfaceId));
        assertTrue(parser.supportsInterface(type(IParserToolingV1).interfaceId));

        assertFalse(parser.supportsInterface(badInterfaceId));
    }
}
