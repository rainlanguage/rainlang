// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {ParseStackOverflow} from "../../../../src/error/ErrParse.sol";

/// @title LibParseStateEndLineUnboundedLHSTest
/// @notice Tests that endLine() enforces MAX_STACK_RHS_OFFSET when adding
/// LHS items to totalRHSTopLevel on empty-RHS input lines.
contract LibParseStateEndLineUnboundedLHSTest is Test {
    using LibParse for ParseState;

    /// External wrapper so vm.expectRevert works.
    function externalParse(string memory s) external view returns (bytes memory, bytes32[] memory) {
        return LibMetaFixture.newState(s).parse();
    }

    /// 62 anonymous LHS items on an empty-RHS source. endLine() sets
    /// totalRHSTopLevel = 62, which is >= MAX_STACK_RHS_OFFSET (0x3e).
    /// Must revert with ParseStackOverflow.
    function testEndLineLHSOverflowAtBoundary() external {
        // Build "_ _ _ ... (62 times) :;".
        bytes memory lhs = new bytes(62 * 2);
        for (uint256 i = 0; i < 62; i++) {
            lhs[i * 2] = "_";
            lhs[i * 2 + 1] = " ";
        }
        string memory rainlang = string(bytes.concat(lhs, bytes(":;")));

        vm.expectRevert(abi.encodeWithSelector(ParseStackOverflow.selector));
        this.externalParse(rainlang);
    }

    /// 61 anonymous LHS items on an empty-RHS source. endLine() sets
    /// totalRHSTopLevel = 61, which is < MAX_STACK_RHS_OFFSET (0x3e).
    /// Must not revert with ParseStackOverflow.
    function testEndLineLHSJustBelowBoundary() external view {
        // Build "_ _ _ ... (61 times) :;".
        bytes memory lhs = new bytes(61 * 2);
        for (uint256 i = 0; i < 61; i++) {
            lhs[i * 2] = "_";
            lhs[i * 2 + 1] = " ";
        }
        string memory rainlang = string(bytes.concat(lhs, bytes(":;")));

        this.externalParse(rainlang);
    }

    /// 255 anonymous LHS items — the maximum a single line can hold
    /// before the LHSItemCountOverflow check. Must revert with
    /// ParseStackOverflow from the endLine() check, not from corruption.
    function testEndLineLHS255Overflow() external {
        // Build "_ _ _ ... (255 times) :;".
        bytes memory lhs = new bytes(255 * 2);
        for (uint256 i = 0; i < 255; i++) {
            lhs[i * 2] = "_";
            lhs[i * 2 + 1] = " ";
        }
        string memory rainlang = string(bytes.concat(lhs, bytes(":;")));

        vm.expectRevert(abi.encodeWithSelector(ParseStackOverflow.selector));
        this.externalParse(rainlang);
    }

    /// Two empty-RHS input lines accumulating past the limit. Each
    /// endLine() call adds that line's LHS count to totalRHSTopLevel.
    /// 32 + 31 = 63 >= 62.
    function testEndLineLHSMultiLineAccumulation() external {
        // Build "_ _ ... (32 times) :,\n_ _ ... (31 times) :;".
        bytes memory line1 = new bytes(32 * 2);
        for (uint256 i = 0; i < 32; i++) {
            line1[i * 2] = "_";
            line1[i * 2 + 1] = " ";
        }
        bytes memory line2 = new bytes(31 * 2);
        for (uint256 i = 0; i < 31; i++) {
            line2[i * 2] = "_";
            line2[i * 2 + 1] = " ";
        }
        string memory rainlang = string(bytes.concat(line1, bytes(":,\n"), line2, bytes(":;")));

        vm.expectRevert(abi.encodeWithSelector(ParseStackOverflow.selector));
        this.externalParse(rainlang);
    }
}
