// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {ParseMemoryOverflow} from "../../../../src/error/ErrParse.sol";

/// @title LibParseParseMemoryOverflowTest
/// @notice Pins that `LibParse.parse()` invokes the parse-memory overflow
/// check itself, rather than leaving it to integrators. The parser's
/// 16-bit relative pointers truncate silently if the free memory pointer
/// exceeds `0x10000`; the only defence is the overflow check, and the
/// only way to guarantee integrators get it is to call it from `parse()`.
contract LibParseParseMemoryOverflowTest is Test {
    using LibParse for ParseState;

    /// External wrapper so `vm.expectRevert` catches the revert across a
    /// call boundary.
    function externalParse(string memory s) external view returns (bytes memory, bytes32[] memory) {
        ParseState memory state = LibMetaFixture.newState(s);
        // Bump the free memory pointer to the boundary. Any further
        // allocation during the parse pushes it past `0x10000` and the
        // overflow check at the end of `parse()` must revert.
        assembly ("memory-safe") {
            mstore(0x40, 0x10000)
        }
        return state.parse();
    }

    /// `parse()` must revert with `ParseMemoryOverflow` when the free
    /// memory pointer ends the parse above `0x10000`. Removing the
    /// `checkParseMemoryOverflow()` call from `parse()` makes this test
    /// silently succeed.
    function testParseChecksParseMemoryOverflow() external {
        vm.expectPartialRevert(ParseMemoryOverflow.selector);
        this.externalParse("_:1;");
    }
}
