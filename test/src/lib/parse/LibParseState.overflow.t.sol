// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ParseTest} from "test/abstract/ParseTest.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {SourceItemOpsOverflow, LineRHSItemsOverflow} from "../../../../src/error/ErrParse.sol";

/// @title LibParseStateOverflowTest
/// @notice Tests that byte-counter overflow guards in LibParseState revert correctly.
contract LibParseStateOverflowTest is ParseTest {
    using LibParse for ParseState;

    /// Builds a balanced binary tree expression with 2^(depth+1)-1 total ops.
    /// Each paren group has exactly 2 inputs so the paren input counter stays
    /// low while the per-item ops counter grows exponentially.
    function buildTree(uint256 depth) internal pure returns (bytes memory) {
        bytes memory s = "a()";
        for (uint256 i = 0; i < depth; i++) {
            s = bytes.concat("a(", s, " ", s, ")");
        }
        return s;
    }

    /// 255 ops in a single top-level item must NOT overflow.
    /// Binary tree depth 7 → 2^8-1 = 255 ops, paren depth 8.
    function testSourceItemOps255NoOverflow() external view {
        string memory s = string(bytes.concat("_: ", buildTree(7), ";"));
        LibMetaFixture.newState(s).parse();
    }

    /// 256+ ops in a single top-level item MUST overflow.
    /// Binary tree depth 8 → 2^9-1 = 511 ops, overflow fires at op 256.
    function testSourceItemOpsOverflow() external {
        string memory s = string(bytes.concat("_: ", buildTree(8), ";"));
        vm.expectRevert(abi.encodeWithSelector(SourceItemOpsOverflow.selector));
        this.parseExternal(s);
    }

    /// 14 top-level RHS items on one line must NOT overflow.
    /// endLine calls snapshotSourceHeadToLineTracker once more, using
    /// the 15th slot (offset 0xF0) which is the last valid position.
    function testLineRHSItems14NoOverflow() external view {
        LibMetaFixture.newState("_ _ _ _ _ _ _ _ _ _ _ _ _ _: a() a() a() a() a() a() a() a() a() a() a() a() a() a();")
            .parse();
    }

    /// 15 top-level RHS items on one line MUST overflow.
    /// The 15th item's snapshot uses offset 0xF0, then endLine's snapshot
    /// attempts offset 0x100 which exceeds the 256-bit lineTracker.
    function testLineRHSItemsOverflow() external {
        vm.expectRevert(abi.encodeWithSelector(LineRHSItemsOverflow.selector));
        this.parseExternal(
            "_ _ _ _ _ _ _ _ _ _ _ _ _ _ _: a() a() a() a() a() a() a() a() a() a() a() a() a() a() a();"
        );
    }
}
