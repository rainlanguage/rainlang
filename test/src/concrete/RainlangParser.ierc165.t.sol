// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {RainlangParser} from "../../../src/concrete/RainlangParser.sol";
import {IParserToolingV1} from "rain.sol.codegen/interface/IParserToolingV1.sol";

contract RainlangParserIERC165Test is Test {
    /// Test that ERC165 is implemented for all interfaces.
    function testRainlangParserIERC165(bytes4 badInterfaceId) external {
        vm.assume(badInterfaceId != type(IERC165).interfaceId);
        vm.assume(badInterfaceId != type(IParserToolingV1).interfaceId);

        RainlangParser parser = new RainlangParser();
        assertTrue(parser.supportsInterface(type(IERC165).interfaceId));
        assertTrue(parser.supportsInterface(type(IParserToolingV1).interfaceId));

        assertFalse(parser.supportsInterface(badInterfaceId));
    }
}
