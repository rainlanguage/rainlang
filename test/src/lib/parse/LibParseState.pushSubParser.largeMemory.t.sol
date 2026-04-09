// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibBytes, Pointer} from "rain.solmem/lib/LibBytes.sol";

/// @title LibParseStatePushSubParserLargeMemoryTest
/// @notice Regression test for the 16-bit pointer truncation bug in
/// pushSubParser. When the free memory pointer exceeds 0xFFFF, the linked
/// list pointer stored in the high bits of subParsers gets truncated,
/// corrupting the list.
contract LibParseStatePushSubParserLargeMemoryTest is Test {
    using LibParseState for ParseState;
    using LibBytes for bytes;

    /// Push the free memory pointer past 0xFFFF, then verify that
    /// pushSubParser + exportSubParsers round-trips correctly.
    function testPushSubParserLargeMemoryOffset() external pure {
        // Allocate enough memory to push the free memory pointer past 0xFFFF.
        bytes memory padding = new bytes(0x20000);
        // Suppress unused variable warning.
        assembly ("memory-safe") {
            pop(padding)
        }

        ParseState memory state;
        state.data = new bytes(32);
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        state.subParsers = 0;

        address addr0 = address(0x1111111111111111111111111111111111111111);
        address addr1 = address(0x2222222222222222222222222222222222222222);
        address addr2 = address(0x3333333333333333333333333333333333333333);

        state.pushSubParser(cursor, bytes32(uint256(uint160(addr0))));
        state.pushSubParser(cursor, bytes32(uint256(uint160(addr1))));
        state.pushSubParser(cursor, bytes32(uint256(uint160(addr2))));

        address[] memory exported = state.exportSubParsers();
        assertEq(exported.length, 3);
        assertEq(exported[0], addr0);
        assertEq(exported[1], addr1);
        assertEq(exported[2], addr2);
    }
}
