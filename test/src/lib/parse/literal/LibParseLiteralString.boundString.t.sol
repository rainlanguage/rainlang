// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibBytes, Pointer} from "rain.solmem/lib/LibBytes.sol";
import {LibParseLiteralString} from "../../../../../src/lib/parse/literal/LibParseLiteralString.sol";
import {LibConformString} from "rain.string/lib/mut/LibConformString.sol";
import {StringTooLong, UnclosedStringLiteral} from "../../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../../src/lib/parse/LibParseError.sol";
import {LibParseState, ParseState} from "../../../../../src/lib/parse/LibParseState.sol";
import {LibAllStandardOps} from "../../../../../src/lib/op/LibAllStandardOps.sol";

/// @title LibParseLiteralStringBoundTest
/// @notice Tests for string literal boundary detection.
contract LibParseLiteralStringBoundTest is Test {
    using LibBytes for bytes;
    using LibParseLiteralString for ParseState;

    /// External parse function to allow us to assert reverts.
    function externalBoundString(bytes memory data) external pure returns (uint256, uint256, uint256, uint256) {
        ParseState memory state = LibParseState.newState(data, "", "", "");
        uint256 cursor = Pointer.unwrap(bytes(data).dataPointer());
        uint256 end = cursor + bytes(data).length;
        (uint256 innerStart, uint256 innerEnd, uint256 outerEnd) = state.boundString(cursor, end);
        return (cursor, innerStart, innerEnd, outerEnd);
    }

    /// External parse function to allow us to assert reverts after forcing the
    /// string length. This can be used to force the parser out of bounds.
    function externalBoundLiteralForceLength(bytes memory data, uint256 length)
        external
        pure
        returns (uint256, uint256, uint256, uint256)
    {
        ParseState memory state = LibParseState.newState(data, "", "", "");
        state.literalParsers = LibAllStandardOps.literalParserFunctionPointers();
        assembly ("memory-safe") {
            mstore(data, length)
        }
        uint256 outerStart = Pointer.unwrap(bytes(data).dataPointer());
        uint256 cursor = outerStart;
        uint256 end = outerStart + length;
        (uint256 innerStart, uint256 innerEnd, uint256 outerEnd) = state.boundString(cursor, end);
        return (outerStart, innerStart, innerEnd, outerEnd);
    }

    function checkStringBounds(
        string memory str,
        uint256 expectedInnerStart,
        uint256 expectedInnerEnd,
        uint256 expectedOuterEnd
    ) internal view {
        (uint256 outerStart, uint256 innerStart, uint256 innerEnd, uint256 outerEnd) =
            this.externalBoundString(bytes(str));
        assertEq(innerStart, outerStart + expectedInnerStart, "innerStart");
        assertEq(innerEnd, outerStart + expectedInnerEnd, "innerEnd");
        assertEq(outerEnd, outerStart + expectedOuterEnd, "outerEnd");
    }

    /// All valid strings should parse with the outer start and end either side
    /// of their quotes and the inner start and end at their data bounds.
    function testParseStringLiteralBounds(string memory str) external view {
        vm.assume(bytes(str).length < 0x20);
        LibConformString.conformValidPrintableStringContent(str);

        checkStringBounds(string.concat("\"", str, "\""), 1, bytes(str).length + 1, bytes(str).length + 2);
    }

    /// Valid but too long strings should error.
    function testParseStringLiteralBoundsTooLong(string memory str) external {
        vm.assume(bytes(str).length >= 0x20);
        LibConformString.conformValidPrintableStringContent(str);

        vm.expectRevert(abi.encodeWithSelector(StringTooLong.selector, LibParseError.tagErrorOffset(0)));
        checkStringBounds(string.concat("\"", str, "\""), 0, 0, 0);
    }

    /// Invalid chars in the first 31 bytes should error.
    function testParseStringLiteralBoundsInvalidCharBefore(string memory str, uint256 badIndex) external {
        vm.assume(bytes(str).length > 0);
        LibConformString.conformValidPrintableStringContent(str);
        badIndex = bound(badIndex, 0, (bytes(str).length > 0x1F ? 0x1F : bytes(str).length) - 1);
        LibConformString.corruptSingleChar(str, badIndex);

        vm.expectRevert(
            abi.encodeWithSelector(UnclosedStringLiteral.selector, LibParseError.tagErrorOffset(1 + badIndex))
        );
        checkStringBounds(string.concat("\"", str, "\""), 0, 0, 0);
    }

    /// Valid string data beyond the bounds of the parsed data should error as
    /// an unclosed string.
    function testParseStringLiteralBoundsParserOutOfBounds(string memory str, uint256 length) external {
        vm.assume(bytes(str).length < 0x20);
        LibConformString.conformValidPrintableStringContent(str);
        str = string.concat("\"", str, "\"");
        length = bound(length, 1, bytes(str).length - 1);

        vm.expectRevert(abi.encodeWithSelector(UnclosedStringLiteral.selector, LibParseError.tagErrorOffset(length)));
        (uint256 outerStart, uint256 innerStart, uint256 innerEnd, uint256 outerEnd) =
            this.externalBoundLiteralForceLength(bytes(str), length);
        (outerStart, innerStart, innerEnd, outerEnd);
    }

    /// UnclosedStringLiteral when end == innerEnd: the closing quote character
    /// is at exactly the end boundary, so there is no room for it.
    function testBoundStringUnclosedAtEndBoundary() external {
        // "hi" — length 4. Force length to 3 so end points at the closing ".
        // innerEnd scans "hi" (2 chars), lands at offset 3 which equals end.
        bytes memory data = bytes("\"hi\"");
        vm.expectRevert(abi.encodeWithSelector(UnclosedStringLiteral.selector, LibParseError.tagErrorOffset(3)));
        this.externalBoundLiteralForceLength(data, 3);
    }

    /// Fuzz variant: any valid string with end set to exclude the closing
    /// quote hits the end == innerEnd branch.
    function testBoundStringUnclosedAtEndBoundaryFuzz(string memory str) external {
        vm.assume(bytes(str).length > 0 && bytes(str).length < 0x20);
        LibConformString.conformValidPrintableStringContent(str);
        bytes memory data = bytes(string.concat("\"", str, "\""));
        // Force length to data.length - 1, placing end at the closing ".
        uint256 length = data.length - 1;
        vm.expectRevert(abi.encodeWithSelector(UnclosedStringLiteral.selector, LibParseError.tagErrorOffset(length)));
        this.externalBoundLiteralForceLength(data, length);
    }
}
