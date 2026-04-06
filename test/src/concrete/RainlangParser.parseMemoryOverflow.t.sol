// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {RainlangParser} from "../../../src/concrete/RainlangParser.sol";
import {ParseMemoryOverflow} from "../../../src/error/ErrParse.sol";

/// Exposes the checkParseMemoryOverflow modifier on a trivial function so it
/// can be tested in isolation without running the real parser.
contract ModifierTestParser is RainlangParser {
    /// Sets the free memory pointer to exactly 0x10000. The modifier should
    /// revert after this function body completes.
    function overflowMemory() external pure checkParseMemoryOverflow {
        assembly ("memory-safe") {
            mstore(0x40, 0x10000)
        }
    }

    /// Does nothing. The modifier should pass because memory stays below
    /// 0x10000.
    function noOverflow() external pure checkParseMemoryOverflow {
        // Free memory pointer stays well below 0x10000.
    }
}

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
