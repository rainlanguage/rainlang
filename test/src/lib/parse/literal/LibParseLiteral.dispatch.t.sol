// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibBytes, Pointer} from "rain.solmem/lib/LibBytes.sol";
import {LibParseState, ParseState} from "../../../../../src/lib/parse/LibParseState.sol";
import {LibParseLiteral, UnsupportedLiteralType} from "../../../../../src/lib/parse/literal/LibParseLiteral.sol";
import {UppercaseHexPrefix} from "../../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../../src/lib/parse/LibParseError.sol";
import {LibAllStandardOps} from "../../../../../src/lib/op/LibAllStandardOps.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";
import {ISubParserV4} from "rain.interpreter.interface/interface/ISubParserV4.sol";
import {LibIntOrAString, IntOrAString} from "rain.intorastring/lib/LibIntOrAString.sol";

/// @title LibParseLiteralDispatchTest
/// @notice Tests for tryParseLiteral dispatch and parseLiteral revert path.
contract LibParseLiteralDispatchTest is Test {
    using LibBytes for bytes;
    using LibParseState for ParseState;
    using LibParseLiteral for ParseState;

    /// External wrapper for parseLiteral so expectRevert works.
    function externalParseLiteral(bytes memory data) external view returns (uint256 newCursor, bytes32 value) {
        ParseState memory state =
            LibParseState.newState(data, "", "", LibAllStandardOps.literalParserFunctionPointers());
        state.literalParsers = LibAllStandardOps.literalParserFunctionPointers();
        uint256 cursor = Pointer.unwrap(data.dataPointer());
        uint256 end = cursor + data.length;
        return state.parseLiteral(cursor, end);
    }

    /// External wrapper for tryParseLiteral.
    function externalTryParseLiteral(bytes memory data)
        external
        view
        returns (bool success, uint256 newCursor, bytes32 value)
    {
        ParseState memory state =
            LibParseState.newState(data, "", "", LibAllStandardOps.literalParserFunctionPointers());
        state.literalParsers = LibAllStandardOps.literalParserFunctionPointers();
        uint256 cursor = Pointer.unwrap(data.dataPointer());
        uint256 end = cursor + data.length;
        return state.tryParseLiteral(cursor, end);
    }

    /// External wrapper for tryParseLiteral with a sub-parser configured.
    function externalTryParseLiteralWithSubParser(bytes memory data, address subParser)
        external
        view
        returns (bool success, uint256 newCursor, bytes32 value)
    {
        ParseState memory state =
            LibParseState.newState(data, "", "", LibAllStandardOps.literalParserFunctionPointers());
        state.literalParsers = LibAllStandardOps.literalParserFunctionPointers();
        state.pushSubParser(0, bytes32(uint256(uint160(subParser))));
        uint256 cursor = Pointer.unwrap(data.dataPointer());
        uint256 end = cursor + data.length;
        return state.tryParseLiteral(cursor, end);
    }

    /// Decimal literal dispatch (head is '1'-'9').
    function testTryParseLiteralDecimal() external view {
        (bool success,,) = this.externalTryParseLiteral(bytes("42 "));
        assertTrue(success, "decimal dispatch");
    }

    /// Hex literal dispatch (head is '0x').
    function testTryParseLiteralHex() external view {
        (bool success,,) = this.externalTryParseLiteral(bytes("0xFF "));
        assertTrue(success, "hex dispatch");
    }

    /// '0' followed by non-'x' routes to decimal, not hex.
    function testTryParseLiteralZeroDecimal() external view {
        (bool success,,) = this.externalTryParseLiteral(bytes("0 "));
        assertTrue(success, "zero decimal dispatch");
    }

    /// String literal dispatch (head is '"').
    function testTryParseLiteralString() external view {
        (bool success,,) = this.externalTryParseLiteral(bytes("\"hi\" "));
        assertTrue(success, "string dispatch");
    }

    /// Unrecognized literal type returns false from tryParseLiteral.
    function testTryParseLiteralUnrecognized() external view {
        // '@' is not a valid literal head.
        (bool success,,) = this.externalTryParseLiteral(bytes("@ "));
        assertFalse(success, "unrecognized returns false");
    }

    /// Negative decimal literal dispatch (head is '-').
    function testTryParseLiteralNegativeDecimal() external view {
        (bool success,,) = this.externalTryParseLiteral(bytes("-1 "));
        assertTrue(success, "negative decimal dispatch");
    }

    /// Hex literal returns the correct parsed value.
    function testTryParseLiteralHexValue() external view {
        (bool success,, bytes32 value) = this.externalTryParseLiteral(bytes("0xFF "));
        assertTrue(success, "hex success");
        assertEq(value, bytes32(uint256(0xFF)), "hex value");
    }

    /// Zero literal returns zero value.
    function testTryParseLiteralZeroValue() external view {
        (bool success,, bytes32 value) = this.externalTryParseLiteral(bytes("0 "));
        assertTrue(success, "zero success");
        assertEq(value, bytes32(0), "zero value");
    }

    /// Uppercase '0X' must revert with UppercaseHexPrefix rather than
    /// silently parsing as decimal 0.
    function testTryParseLiteralUppercaseXReverts() external {
        vm.expectRevert(abi.encodeWithSelector(UppercaseHexPrefix.selector, LibParseError.tagErrorOffset(0)));
        this.externalParseLiteral(bytes("0X "));
    }

    /// Decimal literal returns correct float-encoded value.
    function testTryParseLiteralDecimalValue() external view {
        (bool success,, bytes32 value) = this.externalTryParseLiteral(bytes("42 "));
        assertTrue(success, "decimal success");
        assertEq(value, Float.unwrap(LibDecimalFloat.packLossless(42, 0)), "decimal 42 value");
    }

    /// Sub-parseable literal dispatch (head is '[') reaches the sub-parseable
    /// parser. A mocked sub-parser accepts the literal, proving dispatch
    /// reached the correct branch end-to-end.
    function testTryParseLiteralSubParseableDispatch() external {
        address subParser = makeAddr("subParser");
        bytes32 expectedValue = bytes32(uint256(0x42));

        vm.mockCall(
            subParser, abi.encodeWithSelector(ISubParserV4.subParseLiteral2.selector), abi.encode(true, expectedValue)
        );
        vm.expectCall(subParser, abi.encodeWithSelector(ISubParserV4.subParseLiteral2.selector));

        (bool success,, bytes32 value) = this.externalTryParseLiteralWithSubParser(bytes("[1]"), subParser);
        assertTrue(success, "sub-parseable dispatch");
        assertEq(value, expectedValue, "sub-parseable value");
    }

    /// Multiple unrecognized characters all return false.
    function testTryParseLiteralUnrecognizedMultiple() external view {
        // Safe: single ASCII characters fit in bytes1.
        //forge-lint: disable-next-line(unsafe-typecast)
        bytes1[4] memory chars = [bytes1("@"), bytes1("!"), bytes1("#"), bytes1("$")];
        for (uint256 i = 0; i < chars.length; i++) {
            //forge-lint: disable-next-line(unsafe-typecast)
            (bool success,,) = this.externalTryParseLiteral(abi.encodePacked(chars[i], bytes1(" ")));
            assertFalse(success, string(abi.encodePacked("unrecognized: ", chars[i])));
        }
    }

    /// String literal returns the correct IntOrAString-encoded value.
    function testTryParseLiteralStringValue() external view {
        (bool success,, bytes32 value) = this.externalTryParseLiteral(bytes("\"hi\" "));
        assertTrue(success, "string success");
        assertEq(value, bytes32(IntOrAString.unwrap(LibIntOrAString.fromStringV3("hi"))), "string value");
    }

    /// Negative decimal literal returns correct float-encoded value.
    function testTryParseLiteralNegativeDecimalValue() external view {
        (bool success,, bytes32 value) = this.externalTryParseLiteral(bytes("-1 "));
        assertTrue(success, "negative decimal success");
        assertEq(value, Float.unwrap(LibDecimalFloat.packLossless(-1, 0)), "negative decimal value");
    }

    /// tryParseLiteral advances cursor past the parsed literal.
    function testTryParseLiteralCursorAdvancement() external view {
        bytes memory data = bytes("42 rest");
        (bool success, uint256 newCursor,) = this.externalTryParseLiteral(data);
        assertTrue(success, "cursor advance success");
        uint256 start = Pointer.unwrap(data.dataPointer());
        // "42" is 2 bytes, cursor should advance by 2.
        assertEq(newCursor - start, 2, "cursor advanced past literal");
    }

    /// parseLiteral happy path returns same value as tryParseLiteral.
    function testParseLiteralHappyPath() external view {
        (, bytes32 value) = this.externalParseLiteral(bytes("0xFF "));
        assertEq(value, bytes32(uint256(0xFF)), "parseLiteral hex value");
    }

    /// Hex literal cursor advances past all hex digits.
    function testTryParseLiteralHexCursorAdvancement() external view {
        bytes memory data = bytes("0xABCD rest");
        (bool success, uint256 newCursor,) = this.externalTryParseLiteral(data);
        assertTrue(success, "hex cursor success");
        uint256 start = Pointer.unwrap(data.dataPointer());
        // "0xABCD" is 6 bytes.
        assertEq(newCursor - start, 6, "hex cursor advanced");
    }

    /// String literal cursor advances past closing quote.
    function testTryParseLiteralStringCursorAdvancement() external view {
        bytes memory data = bytes("\"hi\" rest");
        (bool success, uint256 newCursor,) = this.externalTryParseLiteral(data);
        assertTrue(success, "string cursor success");
        uint256 start = Pointer.unwrap(data.dataPointer());
        // '"hi"' is 4 bytes.
        assertEq(newCursor - start, 4, "string cursor advanced");
    }

    /// Negative multi-digit decimal returns correct float-encoded value.
    function testTryParseLiteralNegativeMultiDigit() external view {
        (bool success,, bytes32 value) = this.externalTryParseLiteral(bytes("-42 "));
        assertTrue(success, "negative multi-digit success");
        assertEq(value, Float.unwrap(LibDecimalFloat.packLossless(-42, 0)), "negative 42 value");
    }

    /// Full 32-byte hex literal parses correctly.
    function testTryParseLiteralMaxHex() external view {
        (bool success,, bytes32 value) =
            this.externalTryParseLiteral(bytes("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF "));
        assertTrue(success, "max hex success");
        assertEq(value, bytes32(type(uint256).max), "max hex value");
    }

    /// Empty string literal parses correctly.
    function testTryParseLiteralEmptyString() external view {
        (bool success,, bytes32 value) = this.externalTryParseLiteral(bytes("\"\" "));
        assertTrue(success, "empty string success");
        assertEq(value, bytes32(IntOrAString.unwrap(LibIntOrAString.fromStringV3(""))), "empty string value");
    }

    /// Negative zero parses as decimal zero.
    function testTryParseLiteralNegativeZero() external view {
        (bool success,, bytes32 value) = this.externalTryParseLiteral(bytes("-0 "));
        assertTrue(success, "negative zero success");
        assertEq(value, Float.unwrap(LibDecimalFloat.packLossless(0, 0)), "negative zero value");
    }

    /// Minimum even hex literal parses correctly.
    function testTryParseLiteralMinHex() external view {
        (bool success,, bytes32 value) = this.externalTryParseLiteral(bytes("0x00 "));
        assertTrue(success, "min hex success");
        assertEq(value, bytes32(0), "min hex value");
    }

    /// parseLiteral reverts with UnsupportedLiteralType for unrecognized head.
    function testParseLiteralUnsupportedType() external {
        vm.expectRevert(abi.encodeWithSelector(UnsupportedLiteralType.selector, LibParseError.tagErrorOffset(0)));
        this.externalParseLiteral(bytes("@ "));
    }

    /// A single "0" at the end of the source with 0x78 ('x') as the
    /// next byte in memory must route to decimal, not hex. Without a bounds
    /// check the parser reads past end and sees "0x", incorrectly dispatching
    /// to the hex parser which reverts with ZeroLengthHexLiteral.
    function testTryParseLiteralOOBSecondBytePoison() external view {
        // Allocate data "0" then immediately write 0x78 ('x') right after
        // the data in memory. end = cursor+1 (just the "0" byte), but
        // mload(cursor) reads 32 bytes so byte(1, word) picks up the 'x'.
        bytes memory data = bytes("0");
        uint256 cursor;
        uint256 end;
        assembly ("memory-safe") {
            cursor := add(data, 0x20)
            end := add(cursor, mload(data))
            // Write 'x' immediately after the data content.
            mstore8(end, 0x78)
        }
        ParseState memory state =
            LibParseState.newState(data, "", "", LibAllStandardOps.literalParserFunctionPointers());
        state.literalParsers = LibAllStandardOps.literalParserFunctionPointers();
        // If the bug exists, tryParseLiteral dispatches to hex and reverts.
        (bool success,, bytes32 value) = state.tryParseLiteral(cursor, end);
        assertTrue(success, "single 0 with poison x must parse as decimal");
        assertEq(value, bytes32(0), "single 0 value");
    }
}
