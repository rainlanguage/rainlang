// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {EMPTY_ACTIVE_SOURCE, LibParseState} from "../../../../src/lib/parse/LibParseState.sol";

contract LibParseStateNewActiveSourcePointerTest is Test {
    function checkPointer(uint256 pointer, uint256 expectedSource) internal pure {
        uint256 activeSource;
        assembly ("memory-safe") {
            activeSource := mload(pointer)
        }
        assertEq(activeSource, expectedSource, "unexpected active source");
        assertEq(pointer % 0x20, 0, "new pointer should be aligned");
    }

    /// If the old pointer is zero, the new pointer should point to
    /// EMPTY_ACTIVE_SOURCE.
    /// The fuzzed bytes just ensure the memory pointer is always different.
    function testZeroOldPointer(bytes memory) external pure {
        uint256 oldPointer = 0;
        uint256 newPointer = LibParseState.newActiveSourcePointer(oldPointer);
        checkPointer(newPointer, EMPTY_ACTIVE_SOURCE);
    }

    /// No matter the alignment of the free memory pointer, the new pointer
    /// should always be aligned.
    function testAlignedOldPointer(uint256 offset0, uint256 offset1) external pure {
        uint256 originalPointer0;
        offset0 = bound(offset0, 0, 0x100);
        assembly ("memory-safe") {
            originalPointer0 := mload(0x40)
            mstore(originalPointer0, add(originalPointer0, offset0))
        }
        uint256 newPointer0 = LibParseState.newActiveSourcePointer(0);
        assertTrue(newPointer0 >= originalPointer0, "pointer should be higher");
        checkPointer(newPointer0, EMPTY_ACTIVE_SOURCE);

        /// Do it again, with a different offset.
        uint256 originalPointer1;
        offset1 = bound(offset1, 0, 0x100);
        assembly ("memory-safe") {
            originalPointer1 := mload(0x40)
            mstore(originalPointer1, add(originalPointer1, offset1))
        }
        uint256 newPointer1 = LibParseState.newActiveSourcePointer(newPointer0);
        assertTrue(newPointer1 >= originalPointer1, "pointer should be higher");
        checkPointer(newPointer1, EMPTY_ACTIVE_SOURCE | newPointer0 << 0x10);
    }

    /// If the free memory pointer is aligned, the new pointer should be
    /// the same as the free memory pointer.
    function testPreUnalignedNewPointer() external pure {
        uint256 originalPointer0;
        assembly ("memory-safe") {
            originalPointer0 := mload(0x40)
        }
        uint256 newPointer0 = LibParseState.newActiveSourcePointer(0);
        // Most of the time in Solidity this is true so we shouldn't have to do
        // anything.
        assertTrue(originalPointer0 % 0x20 == 0, "pointer should be prealigned");
        assertEq(newPointer0, originalPointer0, "pointer should be the same");
        checkPointer(newPointer0, EMPTY_ACTIVE_SOURCE);

        // Do it again.
        uint256 originalPointer1;
        assembly ("memory-safe") {
            originalPointer1 := mload(0x40)
        }
        uint256 newPointer1 = LibParseState.newActiveSourcePointer(newPointer0);
        assertTrue(originalPointer1 % 0x20 == 0, "pointer should be prealigned");
        assertEq(newPointer1, originalPointer1, "pointer should be the same");
        checkPointer(newPointer1, EMPTY_ACTIVE_SOURCE | newPointer0 << 0x10);
    }

    /// No matter the content of what the active source pointer points to,
    /// when a new one is created the old content should point to the new
    /// content.
    function testPostUnalignedNewPointer(uint256 activeSource) external pure {
        uint256 activeSourcePtr0 = LibParseState.newActiveSourcePointer(0);
        assembly ("memory-safe") {
            mstore(activeSourcePtr0, activeSource)
        }
        checkPointer(activeSourcePtr0, activeSource);
        uint256 activeSourcePtr1 = LibParseState.newActiveSourcePointer(activeSourcePtr0);
        // The new pointer's content should opint to the old pointer's content.
        checkPointer(activeSourcePtr1, EMPTY_ACTIVE_SOURCE | activeSourcePtr0 << 0x10);
        uint256 activeSource0After;
        assembly ("memory-safe") {
            activeSource0After := mload(activeSourcePtr0)
        }
        assertEq(
            activeSource0After & 0xFFFF,
            activeSourcePtr1,
            "old pointer's content should include new pointer instead of an offset"
        );
    }
}
