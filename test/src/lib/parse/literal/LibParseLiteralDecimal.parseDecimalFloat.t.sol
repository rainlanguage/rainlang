// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {LibParseState, ParseState} from "../../../../../src/lib/parse/LibParseState.sol";
import {LibBytes, Pointer} from "rain.solmem/lib/LibBytes.sol";
import {LibParseLiteralDecimal} from "../../../../../src/lib/parse/literal/LibParseLiteralDecimal.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {ParseEmptyDecimalString} from "rain.string/error/ErrParse.sol";
import {
    ParseDecimalPrecisionLoss,
    MalformedExponentDigits,
    MalformedDecimalPoint
} from "rain.math.float/error/ErrParse.sol";
import {Float, LibDecimalFloat} from "rain.math.float/lib/LibDecimalFloat.sol";
import {LibParseError} from "../../../../../src/lib/parse/LibParseError.sol";

/// @title LibParseLiteralDecimalParseDecimalFloatTest
/// @notice Tests for parsing decimal float literals.
contract LibParseLiteralDecimalParseDecimalFloatTest is Test {
    using LibParseLiteralDecimal for ParseState;
    using LibBytes for bytes;
    using LibDecimalFloat for Float;
    using Strings for uint256;

    function parseDecimalFloatPackedExternal(ParseState memory state)
        external
        pure
        returns (uint256 cursorAfter, bytes32 value)
    {
        return state.parseDecimalFloatPacked(
            Pointer.unwrap(state.data.dataPointer()), Pointer.unwrap(state.data.endDataPointer())
        );
    }

    function checkParseDecimalHappy(string memory data, int256 expectedCoefficient, int256 expectedExponent)
        internal
        view
    {
        ParseState memory state = LibParseState.newState(bytes(data), "", "", "");
        (, bytes32 value) = this.parseDecimalFloatPackedExternal(state);
        Float expected = LibDecimalFloat.packLossless(expectedCoefficient, expectedExponent);
        assertTrue(Float.wrap(value).eq(expected));
    }

    /// Happy-path tests for parseDecimalFloatPacked across a range of
    /// decimal literal forms.
    function testParseDecimalFloatHappyPath() external view {
        // Zero
        checkParseDecimalHappy("0e0", 0, 0);
        // Simple integers
        checkParseDecimalHappy("1e0", 1, 0);
        checkParseDecimalHappy("42e0", 42, 0);
        checkParseDecimalHappy("100e0", 100, 0);
        checkParseDecimalHappy("999e0", 999, 0);
        // Negative coefficient
        checkParseDecimalHappy("-1e0", -1, 0);
        checkParseDecimalHappy("-42e0", -42, 0);
        checkParseDecimalHappy("-999e0", -999, 0);
        // Positive exponents
        checkParseDecimalHappy("1e1", 1, 1);
        checkParseDecimalHappy("1e18", 1, 18);
        checkParseDecimalHappy("5e10", 5, 10);
        checkParseDecimalHappy("1e37", 1, 37);
        // Negative exponents
        checkParseDecimalHappy("1e-1", 1, -1);
        checkParseDecimalHappy("5e-3", 5, -3);
        checkParseDecimalHappy("1e-18", 1, -18);
        checkParseDecimalHappy("1e-37", 1, -37);
        // Negative coefficient with exponents
        checkParseDecimalHappy("-1e18", -1, 18);
        checkParseDecimalHappy("-1e-18", -1, -18);
        checkParseDecimalHappy("-5e-3", -5, -3);
        // Decimal point
        checkParseDecimalHappy("1.5e0", 15, -1);
        checkParseDecimalHappy("0.001e0", 1, -3);
        checkParseDecimalHappy("123.456e0", 123456, -3);
        checkParseDecimalHappy("1.5e2", 15, 1);
        checkParseDecimalHappy("0.1e0", 1, -1);
        checkParseDecimalHappy("99.99e0", 9999, -2);
        // Negative coefficient with decimal point
        checkParseDecimalHappy("-1.5e0", -15, -1);
        checkParseDecimalHappy("-0.001e0", -1, -3);
        checkParseDecimalHappy("-123.456e2", -123456, -1);
        // Large coefficients
        checkParseDecimalHappy("123456789e0", 123456789, 0);
        checkParseDecimalHappy("999999999999999999e0", 999999999999999999, 0);
        // Large exponents with small coefficients
        checkParseDecimalHappy("1e30", 1, 30);
        checkParseDecimalHappy("1e-30", 1, -30);
        // No exponent, integer
        checkParseDecimalHappy("0", 0, 0);
        checkParseDecimalHappy("1", 1, 0);
        checkParseDecimalHappy("42", 42, 0);
        checkParseDecimalHappy("100", 100, 0);
        checkParseDecimalHappy("-1", -1, 0);
        checkParseDecimalHappy("-42", -42, 0);
        checkParseDecimalHappy("123456789", 123456789, 0);
        // No exponent, non-integer
        checkParseDecimalHappy("1.5", 15, -1);
        checkParseDecimalHappy("0.1", 1, -1);
        checkParseDecimalHappy("0.001", 1, -3);
        checkParseDecimalHappy("99.99", 9999, -2);
        checkParseDecimalHappy("123.456", 123456, -3);
        checkParseDecimalHappy("-1.5", -15, -1);
        checkParseDecimalHappy("-0.001", -1, -3);
        checkParseDecimalHappy("-99.99", -9999, -2);
    }

    function checkParseDecimalRevert(string memory data, bytes memory err) internal {
        ParseState memory state = LibParseState.newState(bytes(data), "", "", "");
        vm.expectRevert(err);
        this.parseDecimalFloatPackedExternal(state);
    }

    /// An empty string should revert.
    function testParseLiteralDecimalFloatEmpty() external {
        checkParseDecimalRevert(
            "", abi.encodeWithSelector(ParseEmptyDecimalString.selector, LibParseError.tagErrorOffset(0))
        );
    }

    /// A non decimal string should revert.
    function testParseLiteralDecimalFloatNonDecimal() external {
        checkParseDecimalRevert(
            "hello", abi.encodeWithSelector(ParseEmptyDecimalString.selector, LibParseError.tagErrorOffset(0))
        );
    }

    /// e without a number should revert.
    function testParseLiteralDecimalFloatExponentRevert() external {
        checkParseDecimalRevert(
            "e", abi.encodeWithSelector(ParseEmptyDecimalString.selector, LibParseError.tagErrorOffset(0))
        );
    }

    /// e with a left digit but not right should revert.
    function testParseLiteralDecimalFloatExponentRevert2() external {
        checkParseDecimalRevert(
            "1e", abi.encodeWithSelector(MalformedExponentDigits.selector, LibParseError.tagErrorOffset(2))
        );
    }

    /// e with a left digit but not right should revert. Add a negative sign.
    function testParseLiteralDecimalFloatExponentRevert3() external {
        checkParseDecimalRevert(
            "1e-", abi.encodeWithSelector(MalformedExponentDigits.selector, LibParseError.tagErrorOffset(3))
        );
    }

    /// e with a right digit but not left should revert.
    function testParseLiteralDecimalFloatExponentRevert4() external {
        checkParseDecimalRevert(
            "e1", abi.encodeWithSelector(ParseEmptyDecimalString.selector, LibParseError.tagErrorOffset(0))
        );
    }

    /// e with a right digit but not left should revert.
    /// two digits.
    function testParseLiteralDecimalFloatExponentRevert5() external {
        checkParseDecimalRevert(
            "e10", abi.encodeWithSelector(ParseEmptyDecimalString.selector, LibParseError.tagErrorOffset(0))
        );
    }

    /// e with a right digit but not left should revert.
    /// two digits with negative sign.
    function testParseLiteralDecimalFloatExponentRevert6() external {
        checkParseDecimalRevert(
            "e-10", abi.encodeWithSelector(ParseEmptyDecimalString.selector, LibParseError.tagErrorOffset(0))
        );
    }

    /// Dot without digits should revert.
    function testParseLiteralDecimalFloatDotRevert() external {
        checkParseDecimalRevert(
            ".", abi.encodeWithSelector(ParseEmptyDecimalString.selector, LibParseError.tagErrorOffset(0))
        );
    }

    /// Dot without leading digits should revert.
    function testParseLiteralDecimalFloatDotRevert2() external {
        checkParseDecimalRevert(
            ".1", abi.encodeWithSelector(ParseEmptyDecimalString.selector, LibParseError.tagErrorOffset(0))
        );
    }

    /// Dot without trailing digits should revert.
    function testParseLiteralDecimalFloatDotRevert3() external {
        checkParseDecimalRevert(
            "1.", abi.encodeWithSelector(MalformedDecimalPoint.selector, LibParseError.tagErrorOffset(2))
        );
    }

    /// Dot e is an error.
    function testParseLiteralDecimalFloatDotE() external {
        checkParseDecimalRevert(
            ".e", abi.encodeWithSelector(ParseEmptyDecimalString.selector, LibParseError.tagErrorOffset(0))
        );
    }

    /// Dot e0 is an error.
    function testParseLiteralDecimalFloatDotE0() external {
        checkParseDecimalRevert(
            ".e0", abi.encodeWithSelector(ParseEmptyDecimalString.selector, LibParseError.tagErrorOffset(0))
        );
    }

    /// e dot is an error.
    function testParseLiteralDecimalFloatEDot() external {
        checkParseDecimalRevert(
            "e.", abi.encodeWithSelector(ParseEmptyDecimalString.selector, LibParseError.tagErrorOffset(0))
        );
    }

    /// Negative e with no digits is an error.
    function testParseLiteralDecimalFloatNegativeE() external {
        checkParseDecimalRevert(
            "0.0e-", abi.encodeWithSelector(MalformedExponentDigits.selector, LibParseError.tagErrorOffset(5))
        );
    }

    /// Negative frac is an error.
    function testParseLiteralDecimalFloatNegativeFrac() external {
        checkParseDecimalRevert(
            "0.-1", abi.encodeWithSelector(MalformedDecimalPoint.selector, LibParseError.tagErrorOffset(2))
        );
    }

    /// Can't have more than max total precision. Add decimals after the max int.
    function testParseLiteralDecimalFloatPrecisionRevert0() external {
        checkParseDecimalRevert(
            "57896044618658097711785492504343953926634992332820282019728792003956564819967.1",
            abi.encodeWithSelector(ParseDecimalPrecisionLoss.selector, LibParseError.tagErrorOffset(79))
        );
    }

    /// Can't have more than max total precision. Have an int that makes it
    /// impossible to fit the max decimals.
    function testParseLiteralDecimalFloatPrecisionRevert1() external {
        checkParseDecimalRevert(
            "1.57896044618658097711785492504343953926634992332820282019728792003956564819967",
            abi.encodeWithSelector(ParseDecimalPrecisionLoss.selector, LibParseError.tagErrorOffset(79))
        );
    }
}
