// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {LibBytes, Pointer} from "rain-solmem-0.1.28/src/lib/LibBytes.sol";
import {LibParseSprite} from "../../../../src/lib/parse/LibParseSprite.sol";

contract LibParseSpriteRegionEqualsTest is Test {
    using LibBytes for bytes;

    function spriteFromSeed(bytes32 seed) internal pure returns (bytes memory) {
        bytes memory sprite;
        for (uint256 i = 0; i < 0x18; i++) {
            sprite = bytes.concat(sprite, keccak256(abi.encode(seed, i)));
        }
        return sprite;
    }

    /// For every entry length a byte can hold, at an offset below 256 and the
    /// same offset plus 256, a region equals the entry only with exactly its
    /// bytes: a region one byte longer or shorter, with memory continuing the
    /// entry's bytes, or with its first or last byte changed, does not.
    function testRegionEqualsExactlyTheEntryBytes(bytes32 seed, uint256 offset) external pure {
        bytes memory sprite = spriteFromSeed(seed);
        offset = bound(offset, 0, 0xFF);
        bytes memory region = bytes.concat(sprite);
        for (uint256 entryOffset = offset; entryOffset <= offset + 0x100; entryOffset += 0x100) {
            uint256 start = Pointer.unwrap(region.dataPointer()) + entryOffset;
            for (uint256 length = 0; length <= 0xFF; length++) {
                uint256 entry = (entryOffset << 8) | length;
                assertTrue(LibParseSprite.regionEquals(sprite, start, start + length, entry), "equal");
                assertFalse(LibParseSprite.regionEquals(sprite, start, start + length + 1, entry), "longer");
                if (length > 0) {
                    assertFalse(LibParseSprite.regionEquals(sprite, start, start + length - 1, entry), "shorter");
                    region[entryOffset] ^= 0x01;
                    assertFalse(LibParseSprite.regionEquals(sprite, start, start + length, entry), "first byte");
                    region[entryOffset] ^= 0x01;
                    region[entryOffset + length - 1] ^= 0x01;
                    assertFalse(LibParseSprite.regionEquals(sprite, start, start + length, entry), "last byte");
                    region[entryOffset + length - 1] ^= 0x01;
                }
            }
        }
    }
}
