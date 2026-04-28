// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {ParseMemoryOverflow} from "../../../../src/error/ErrParse.sol";

/// @title LibParseStateCheckParseMemoryOverflowTest
/// @notice Tests that `LibParseState.checkParseMemoryOverflow` reverts when the free
/// memory pointer reaches or exceeds 0x10000 and passes when it stays below.
contract LibParseStateCheckParseMemoryOverflowTest is Test {
    /// Must not revert when the free memory pointer is below 0x10000.
    function testCheckParseMemoryOverflowBelow(uint256 ptr) external pure {
        ptr = bound(ptr, 0, 0xFFFF);
        assembly ("memory-safe") {
            mstore(0x40, ptr)
        }
        LibParseState.checkParseMemoryOverflow();
    }

    /// Must revert with `ParseMemoryOverflow` when the free memory pointer
    /// is exactly 0x10000.
    function testCheckParseMemoryOverflowExact() external {
        vm.expectRevert(abi.encodeWithSelector(ParseMemoryOverflow.selector, uint256(0x10000)));
        this.externalOverflow(0x10000);
    }

    /// Must revert with `ParseMemoryOverflow` when the free memory pointer
    /// exceeds 0x10000. Bounded to `type(uint24).max` to avoid EVM-level
    /// memory faults from extremely large pointer values.
    function testCheckParseMemoryOverflowAbove(uint256 ptr) external {
        ptr = bound(ptr, 0x10000, type(uint24).max);
        vm.expectRevert(abi.encodeWithSelector(ParseMemoryOverflow.selector, ptr));
        this.externalOverflow(ptr);
    }

    /// External helper so `vm.expectRevert` can catch the revert across a
    /// call boundary.
    function externalOverflow(uint256 ptr) external pure {
        assembly ("memory-safe") {
            mstore(0x40, ptr)
        }
        LibParseState.checkParseMemoryOverflow();
    }
}
