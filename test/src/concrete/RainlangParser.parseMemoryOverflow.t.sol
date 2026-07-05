// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {ParseMemoryOverflow} from "../../../src/error/ErrParse.sol";
import {ModifierTestParser} from "./ModifierTestParser.sol";

contract RainlangParserParseMemoryOverflowTest is Test {
    /// The modifier must revert when the free memory pointer exceeds the
    /// 16-bit range.
    function testCheckParseMemoryOverflowReverts() external {
        ModifierTestParser parser = new ModifierTestParser();
        vm.expectRevert(abi.encodeWithSelector(ParseMemoryOverflow.selector, uint256(0x10000)));
        parser.overflowMemory();
    }

    /// The modifier must not revert when the free memory pointer stays
    /// below 0x10000.
    function testCheckParseMemoryOverflowPasses() external {
        ModifierTestParser parser = new ModifierTestParser();
        parser.noOverflow();
    }
}
