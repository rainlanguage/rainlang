// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {ParseStackOverflow} from "../../../../src/error/ErrParse.sol";

contract LibParseStateHighwaterOverflowTest is Test {
    using LibParseState for ParseState;

    /// External wrapper so expectRevert works.
    function externalHighwaterOverflow() external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");
        // Set the RHS offset (first byte of topLevel0) to 0x3d so the
        // next highwater() call increments it to 0x3e and triggers
        // ParseStackOverflow.
        state.topLevel0 = uint256(0x3d) << 248;
        state.highwater();
    }

    /// External wrapper for the just-below-boundary case.
    function externalHighwaterJustBelowOverflow() external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");
        // Set the RHS offset to 0x3c so highwater() increments to 0x3d,
        // which is just below the 0x3e overflow threshold.
        state.topLevel0 = uint256(0x3c) << 248;
        state.highwater();
    }

    /// highwater() must NOT revert when the RHS offset is just below
    /// the overflow boundary (0x3c → 0x3d).
    function testHighwaterJustBelowOverflow() external view {
        this.externalHighwaterJustBelowOverflow();
    }

    /// highwater() must revert with ParseStackOverflow when the RHS
    /// offset reaches 0x3e.
    function testHighwaterOverflow() external {
        vm.expectRevert(abi.encodeWithSelector(ParseStackOverflow.selector));
        this.externalHighwaterOverflow();
    }
}
