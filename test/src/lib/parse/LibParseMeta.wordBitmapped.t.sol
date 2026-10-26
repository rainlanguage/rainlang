// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";

import {LibParseMeta, FINGERPRINT_MASK} from "../../../../src/lib/parse/LibParseMeta.sol";

contract LitParseMetaTest is Test {
    function referenceWordBitmapped(uint256 seed, bytes32 word) public pure returns (uint256 bitmap, uint256 hashed) {
        // taking the low byte of the seed is intentional.
        //forge-lint: disable-next-line(unsafe-typecast)
        hashed = uint256(keccak256(abi.encodePacked(word, uint8(seed))));
        // Taking the type byte of hashed only.
        //forge-lint: disable-next-line(unsafe-typecast, incorrect-shift)
        bitmap = 1 << uint256(uint8(uint256(hashed) >> 0xF8));
        // Fingerprint 0 is reserved as the empty-slot sentinel, so force
        // it to 1 when the low 3 bytes are zero.
        if (hashed & FINGERPRINT_MASK == 0) {
            hashed = 1;
        }
    }

    function testWordBitmapped(uint256 seed, bytes32 word) public pure {
        (uint256 bitmap, uint256 hashed) = LibParseMeta.wordBitmapped(seed, word);
        (uint256 refBitmap, uint256 refHashed) = referenceWordBitmapped(seed, word);
        assertEq(bitmap, refBitmap, "bitmap");
        assertEq(hashed, refHashed, "hashed");
    }

    /// The fingerprint (low 3 bytes of hashed) must never be zero, because
    /// zero is the empty-slot sentinel in buildParseMetaV2.
    function testWordBitmappedFingerprintNonZero(uint256 seed, bytes32 word) public pure {
        (, uint256 hashed) = LibParseMeta.wordBitmapped(seed, word);
        assertTrue(hashed & FINGERPRINT_MASK != 0, "fingerprint must not be zero");
    }
}
