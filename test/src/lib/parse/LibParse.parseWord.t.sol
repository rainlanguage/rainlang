// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {Pointer, LibBytes} from "rain.solmem/lib/LibBytes.sol";
import {LibParseSlow} from "./LibParseSlow.sol";
import {CMASK_NUMERIC_0_9} from "rain.string/lib/parse/LibParseCMask.sol";
import {WordSize} from "../../../../src/error/ErrParse.sol";

/// @title LibParseParseWordTest
/// @notice Tests LibParse's parseWord function.
contract LibParseParseWordTest is Test {
    using LibBytes for bytes;

    /// Test parse word against a reference implementation.
    /// For all input bytes length [1,31] the two implementations will agree.
    /// Length 0 is undefined behaviour for word parsing so is not tested.
    /// Length 32+ will error on the real implementation so is not tested.
    function testLibParseParseWordReferenceImplementation(bytes memory data, uint256 mask) external pure {
        vm.assume(data.length <= 31);
        vm.assume(data.length > 0);
        uint256 cursor = Pointer.unwrap(data.dataPointer());
        uint256 end = cursor + data.length;

        uint256 i = LibParseSlow.parseWordSlow(data, mask);

        (uint256 cursorAfter, bytes32 word) = LibParse.parseWord(cursor, end, mask);
        assertEq(cursorAfter - cursor, i);
        assertTrue(i <= data.length);

        bytes32 expectedWord;
        assembly ("memory-safe") {
            expectedWord := mload(add(data, 0x20))
        }
        expectedWord &= bytes32(~(2 ** (256 - (i * 8)) - 1));
        assertEq(word, expectedWord);
    }

    function checkParseWord(bytes memory data, uint256 mask, uint256 expectedI, bytes32 expectedWord) public pure {
        uint256 cursor = Pointer.unwrap(data.dataPointer());
        uint256 end = cursor + data.length;

        (uint256 cursorAfter, bytes32 word) = LibParse.parseWord(cursor, end, mask);
        assertEq(cursorAfter - cursor, expectedI);
        assertEq(word, expectedWord);
    }

    /// Test some examples of parsing words from a byte array.
    function testLibParseParseWordExamples() external {
        // Casting a small literal is safe to typecast.
        //forge-lint: disable-next-line(unsafe-typecast)
        checkParseWord("a", type(uint256).max, 1, bytes32(bytes("a")));
        // Casting a small literal is safe to typecast.
        //forge-lint: disable-next-line(unsafe-typecast)
        checkParseWord("ab", type(uint256).max, 2, bytes32(bytes("ab")));
        // Casting a small literal is safe to typecast.
        //forge-lint: disable-next-line(unsafe-typecast)
        checkParseWord("abc", type(uint256).max, 3, bytes32(bytes("abc")));
        // Casting a small literal is safe to typecast.
        //forge-lint: disable-next-line(unsafe-typecast)
        checkParseWord("a", CMASK_NUMERIC_0_9, 1, bytes32(bytes("a")));
        // Casting a small literal is safe to typecast.
        //forge-lint: disable-next-line(unsafe-typecast)
        checkParseWord("ab", CMASK_NUMERIC_0_9, 1, bytes32(bytes("a")));
        // Casting a small literal is safe to typecast.
        //forge-lint: disable-next-line(unsafe-typecast)
        checkParseWord("a1", CMASK_NUMERIC_0_9, 2, bytes32(bytes("a1")));
        // Casting a small literal is safe to typecast.
        //forge-lint: disable-next-line(unsafe-typecast)
        checkParseWord("a1b", CMASK_NUMERIC_0_9, 2, bytes32(bytes("a1")));
        // Casting a small literal is safe to typecast.
        //forge-lint: disable-next-line(unsafe-typecast)
        checkParseWord("a1b2", CMASK_NUMERIC_0_9, 2, bytes32(bytes("a1")));
        // Casting a small literal is safe to typecast.
        //forge-lint: disable-next-line(unsafe-typecast)
        checkParseWord("a12c", CMASK_NUMERIC_0_9, 3, bytes32(bytes("a12")));
        checkParseWord(
            "0123456789012345678901234567890",
            CMASK_NUMERIC_0_9,
            31,
            // Casting a small literal is safe to typecast.
            //forge-lint: disable-next-line(unsafe-typecast)
            bytes32(bytes("0123456789012345678901234567890"))
        );

        vm.expectRevert(abi.encodeWithSelector(WordSize.selector, "01234567890123456789012345678901"));
        this.checkParseWord(
            "01234567890123456789012345678901",
            CMASK_NUMERIC_0_9,
            31,
            // Casting a small literal is safe to typecast.
            //forge-lint: disable-next-line(unsafe-typecast)
            bytes32(bytes("0123456789012345678901234567890"))
        );
    }

    /// Check that bytes that words that are too long always error.
    function testLibParseParseWordTooLong(bytes memory data) external {
        vm.assume(data.length > 31);
        // Always the first 32 bytes are visible in the error.
        bytes32 wordInError;
        assembly ("memory-safe") {
            wordInError := mload(add(data, 0x20))
        }
        vm.expectRevert(abi.encodeWithSelector(WordSize.selector, abi.encode(wordInError)));
        // No truncation for an empty string.
        //forge-lint: disable-next-line(unsafe-typecast)
        this.checkParseWord(data, type(uint256).max, 0, bytes32(bytes("")));
    }

    /// Ensure that parse word can't exceed the end even if there are valid
    /// looking bytes in memory.
    function testLibParseParseWordEnd(uint256 length) external pure {
        length = bound(length, 1, 0x1F);
        bytes memory data = "01234567890123456789012345678901";
        assembly ("memory-safe") {
            mstore(data, length)
        }
        uint256 cursor = Pointer.unwrap(data.dataPointer());
        uint256 end = cursor + data.length;

        (uint256 cursorAfter, bytes32 word) = LibParse.parseWord(cursor, end, CMASK_NUMERIC_0_9);
        assertEq(cursorAfter - cursor, length);
        // Data has fixed length so we can typecast.
        //forge-lint: disable-next-line(unsafe-typecast)
        assertEq(word, bytes32(data));
    }
}
