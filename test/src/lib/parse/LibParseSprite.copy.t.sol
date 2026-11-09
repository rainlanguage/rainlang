// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {LibBytes, Pointer} from "rain-solmem-0.1.28/src/lib/LibBytes.sol";
import {LibParseSprite} from "../../../../src/lib/parse/LibParseSprite.sol";

contract LibParseSpriteCopyTest is Test {
    using LibBytes for bytes;

    /// Every entry of up to a word lands at the cursor and the returned
    /// cursor is past it.
    function testCopyEveryLengthUpToAWord(bytes memory sprite, uint256 offset) external pure {
        sprite = bytes.concat(sprite, new bytes(0x20));
        offset = bound(offset, 0, sprite.length - 0x20);
        for (uint256 length = 0; length <= 0x20; length++) {
            bytes memory target = new bytes(0x40);
            uint256 cursor = Pointer.unwrap(target.dataPointer());
            uint256 cursorAfter = LibParseSprite.copy(sprite, cursor, (offset << 8) | length);
            assertEq(cursorAfter, cursor + length, "cursor");
            for (uint256 i = 0; i < length; i++) {
                assertEq(target[i], sprite[offset + i], "byte");
            }
        }
    }
}
