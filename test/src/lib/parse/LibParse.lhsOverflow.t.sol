// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {RainlangParser} from "../../../../src/concrete/RainlangParser.sol";
import {LHSItemCountOverflow} from "../../../../src/error/ErrParse.sol";

/// @title LibParseLHSOverflowTest
/// @notice A single-byte counter in lineTracker and topLevel1 tracks LHS item
/// counts. If more than 255 items are parsed, the increment carries into the
/// adjacent byte, silently corrupting parser state. This test verifies that
/// the parser reverts before the carry-over can occur.
contract LibParseLHSOverflowTest is Test {
    RainlangParser internal parser;

    function setUp() external {
        parser = new RainlangParser();
    }

    /// External wrapper so vm.expectRevert works.
    function externalUnsafeParse(bytes memory data) external view returns (bytes memory, bytes32[] memory) {
        return parser.unsafeParse(data);
    }

    /// 256 anonymous LHS items on a single line overflows both lineTracker
    /// (per-line counter) and topLevel1 (per-source counter). The parser
    /// must revert with LHSItemCountOverflow, not silently corrupt state.
    function testLHSItemCountOverflow256() external {
        // Build "_ _ _ ... (256 times) _ :;"
        bytes memory data = new bytes(256 * 2 + 2);
        for (uint256 i = 0; i < 256; i++) {
            data[i * 2] = "_";
            data[i * 2 + 1] = " ";
        }
        data[512] = ":";
        data[513] = ";";

        // The call must revert with LHSItemCountOverflow specifically.
        // Before the fix, it reverts with ExcessRHSItems (wrong error from
        // corruption), causing this assertion to fail.
        try this.externalUnsafeParse(data) {
            revert("expected revert, got success");
        } catch (bytes memory reason) {
            bytes4 selector;
            assembly ("memory-safe") {
                selector := mload(add(reason, 0x20))
            }
            assertEq(selector, LHSItemCountOverflow.selector, "must revert with LHSItemCountOverflow");
        }
    }

    /// 255 anonymous LHS items is the maximum valid count — must not revert
    /// with the overflow error.
    function testLHSItemCount255() external view {
        // Build "_ _ _ ... (255 times) _ :;"
        bytes memory data = new bytes(255 * 2 + 2);
        for (uint256 i = 0; i < 255; i++) {
            data[i * 2] = "_";
            data[i * 2 + 1] = " ";
        }
        data[510] = ":";
        data[511] = ";";

        // This should not revert with LHSItemCountOverflow.
        // It may revert with a different error (e.g. too many top-level items
        // for the 62-slot limit), but NOT the byte overflow error.
        try this.externalUnsafeParse(data) {}
        catch (bytes memory reason) {
            bytes4 selector;
            assembly ("memory-safe") {
                selector := mload(add(reason, 0x20))
            }
            assertTrue(selector != LHSItemCountOverflow.selector, "255 items must not trigger overflow");
        }
    }
}
