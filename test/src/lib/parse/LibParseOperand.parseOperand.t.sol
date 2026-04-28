// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseOperand} from "../../../../src/lib/parse/LibParseOperand.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibBytes, Pointer} from "rain.solmem/lib/LibBytes.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {LibConformString} from "rain.string/lib/mut/LibConformString.sol";
import {OperandValuesOverflow, UnclosedOperand} from "../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";

contract LibParseOperandParseOperandTest is Test {
    using LibBytes for bytes;
    using LibParseOperand for ParseState;
    using Strings for uint256;
    using Strings for int256;

    function checkParsingOperandFromData(string memory s, bytes32[] memory expectedValues, uint256 expectedEnd)
        public
        view
    {
        ParseState memory state = LibMetaFixture.newState(s);
        // Before parsing any operand values the state gets initialized at the
        // max length of 4.
        assertEq(state.operandValues.length, 4);

        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        uint256 end = cursor + state.data.length;

        uint256 cursorAfter = state.parseOperand(cursor, end);

        assertEq(cursorAfter - cursor, expectedEnd);

        assertEq(expectedValues.length, state.operandValues.length);
        for (uint256 i = 0; i < expectedValues.length; i++) {
            assertEq(expectedValues[i], state.operandValues[i]);
        }
    }

    // Test that parsing a string that doesn't start with the operand opening
    // character always results in a zero length operand values array.
    /// forge-config: default.fuzz.runs = 100
    function testParseOperandNoOpeningCharacter(string memory s) external view {
        vm.assume(bytes(s).length > 0);
        vm.assume(bytes(s)[0] != "<");

        checkParsingOperandFromData(s, new bytes32[](0), 0);
    }

    // Test that parsing an empty "<>" operand results in a zero length operand
    // values array. The cursor moves past both the opening and closing
    // characters.
    /// forge-config: default.fuzz.runs = 100
    function testParseOperandEmptyOperand(string memory s) external view {
        vm.assume(bytes(s).length > 2);
        bytes(s)[0] = "<";
        bytes(s)[1] = ">";

        checkParsingOperandFromData(s, new bytes32[](0), 2);
    }

    // Test that we can parse a single literal.
    /// forge-config: default.fuzz.runs = 100
    function testParseOperandSingleDecimalLiteral(
        bool asHex,
        int256 value,
        string memory maybeWhitespaceA,
        string memory maybeWhitespaceB,
        string memory suffix
    ) external view {
        LibConformString.conformStringToWhitespace(maybeWhitespaceA);
        LibConformString.conformStringToWhitespace(maybeWhitespaceB);

        value = bound(value, 0, type(int224).max);

        // Casting an int256 to uint256 does not truncate, and is required to
        // build a hex string.
        //forge-lint: disable-next-line(unsafe-typecast)
        string memory valueString = asHex ? uint256(value).toHexString() : value.toStringSigned();
        string memory s = string.concat("<", maybeWhitespaceA, valueString, maybeWhitespaceB, ">", suffix);

        bytes32[] memory expectedValues = new bytes32[](1);
        // Casting an int256 to uint256 does not truncate.
        //forge-lint: disable-next-line(unsafe-typecast)
        expectedValues[0] = asHex ? bytes32(uint256(value)) : Float.unwrap(LibDecimalFloat.packLossless(value, 0));

        checkParsingOperandFromData(
            s,
            expectedValues,
            bytes(valueString).length + 2 + bytes(maybeWhitespaceA).length + bytes(maybeWhitespaceB).length
        );
    }

    // Test that we can parse two literals.
    /// forge-config: default.fuzz.runs = 100
    function testParseOperandTwoDecimalLiterals(
        bool asHexA,
        bool asHexB,
        int256 valueA,
        int256 valueB,
        string memory maybeWhitespaceA,
        string memory maybeWhitespaceB,
        string memory maybeWhitespaceC,
        string memory suffix
    ) external view {
        vm.assume(bytes(maybeWhitespaceB).length > 0);

        valueA = bound(valueA, 0, type(int224).max);
        valueB = bound(valueB, 0, type(int224).max);

        LibConformString.conformStringToWhitespace(maybeWhitespaceA);
        LibConformString.conformStringToWhitespace(maybeWhitespaceB);
        LibConformString.conformStringToWhitespace(maybeWhitespaceC);

        // Casting an int256 to uint256 does not truncate, and is required to
        // build a hex string.
        //forge-lint: disable-next-line(unsafe-typecast)
        string memory valueAString = asHexA ? uint256(valueA).toHexString() : valueA.toStringSigned();
        //forge-lint: disable-next-line(unsafe-typecast)
        string memory valueBString = asHexB ? uint256(valueB).toHexString() : valueB.toStringSigned();

        string memory s = string.concat(
            "<", maybeWhitespaceA, valueAString, maybeWhitespaceB, valueBString, maybeWhitespaceC, ">", suffix
        );

        bytes32[] memory expectedValues = new bytes32[](2);
        // Casting int256 to uint256 does not truncate, and is required to get
        // to the bytes32 cast.
        //forge-lint: disable-next-line(unsafe-typecast)
        expectedValues[0] = (asHexA ? bytes32(uint256(valueA)) : Float.unwrap(LibDecimalFloat.packLossless(valueA, 0)));
        //forge-lint: disable-next-line(unsafe-typecast)
        expectedValues[1] = (asHexB ? bytes32(uint256(valueB)) : Float.unwrap(LibDecimalFloat.packLossless(valueB, 0)));

        checkParsingOperandFromData(
            s,
            expectedValues,
            bytes(valueAString).length + bytes(valueBString).length + 2 + bytes(maybeWhitespaceA).length
                + bytes(maybeWhitespaceB).length + bytes(maybeWhitespaceC).length
        );
    }

    // Test that we can parse three literals.
    /// forge-config: default.fuzz.runs = 100
    function testParseOperandThreeDecimalLiterals(
        bool asHexA,
        bool asHexB,
        bool asHexC,
        int256 valueA,
        int256 valueB,
        int256 valueC,
        string memory maybeWhitespaceA,
        string memory maybeWhitespaceB,
        string memory maybeWhitespaceC,
        string memory maybeWhitespaceD,
        string memory suffix
    ) external view {
        vm.assume(bytes(maybeWhitespaceB).length > 0);
        vm.assume(bytes(maybeWhitespaceC).length > 0);

        valueA = bound(valueA, 0, type(int224).max);
        valueB = bound(valueB, 0, type(int224).max);
        valueC = bound(valueC, 0, type(int224).max);

        LibConformString.conformStringToWhitespace(maybeWhitespaceA);
        LibConformString.conformStringToWhitespace(maybeWhitespaceB);
        LibConformString.conformStringToWhitespace(maybeWhitespaceC);
        LibConformString.conformStringToWhitespace(maybeWhitespaceD);

        string memory s;
        uint256 expectedLength;
        {
            // Casting an int256 to uint256 does not truncate, and is required to
            // build a hex string.
            //forge-lint: disable-next-line(unsafe-typecast)
            string memory valueAString = asHexA ? uint256(valueA).toHexString() : valueA.toStringSigned();
            //forge-lint: disable-next-line(unsafe-typecast)
            string memory valueBString = asHexB ? uint256(valueB).toHexString() : valueB.toStringSigned();
            //forge-lint: disable-next-line(unsafe-typecast)
            string memory valueCString = asHexC ? uint256(valueC).toHexString() : valueC.toStringSigned();

            s = string.concat(
                string.concat(
                    "<", maybeWhitespaceA, valueAString, maybeWhitespaceB, valueBString, maybeWhitespaceC, valueCString
                ),
                maybeWhitespaceD,
                ">",
                suffix
            );

            expectedLength = bytes(valueAString).length + bytes(valueBString).length + bytes(valueCString).length + 2
                + bytes(maybeWhitespaceA).length + bytes(maybeWhitespaceB).length + bytes(maybeWhitespaceC).length
                + bytes(maybeWhitespaceD).length;
        }

        bytes32[] memory expectedValues = new bytes32[](3);
        // Casting int256 to uint256 does not truncate, and is required to get
        // to the bytes32 cast.
        //forge-lint: disable-next-line(unsafe-typecast)
        expectedValues[0] = (asHexA ? bytes32(uint256(valueA)) : Float.unwrap(LibDecimalFloat.packLossless(valueA, 0)));
        //forge-lint: disable-next-line(unsafe-typecast)
        expectedValues[1] = (asHexB ? bytes32(uint256(valueB)) : Float.unwrap(LibDecimalFloat.packLossless(valueB, 0)));
        //forge-lint: disable-next-line(unsafe-typecast)
        expectedValues[2] = (asHexC ? bytes32(uint256(valueC)) : Float.unwrap(LibDecimalFloat.packLossless(valueC, 0)));

        checkParsingOperandFromData(s, expectedValues, expectedLength);
    }

    // Test that we can parse four literals.
    /// forge-config: default.fuzz.runs = 100
    function testParseOperandFourDecimalLiterals(
        bool[4] memory asHex,
        int256[4] memory values,
        string[5] memory maybeWhitespace,
        string memory suffix
    ) external view {
        {
            vm.assume(bytes(maybeWhitespace[1]).length > 0);
            vm.assume(bytes(maybeWhitespace[2]).length > 0);
            vm.assume(bytes(maybeWhitespace[3]).length > 0);
            LibConformString.conformStringToWhitespace(maybeWhitespace[0]);
            LibConformString.conformStringToWhitespace(maybeWhitespace[1]);
            LibConformString.conformStringToWhitespace(maybeWhitespace[2]);
            LibConformString.conformStringToWhitespace(maybeWhitespace[3]);
            LibConformString.conformStringToWhitespace(maybeWhitespace[4]);
        }

        for (uint256 i = 0; i < 4; i++) {
            values[i] = bound(values[i], 0, type(int224).max);
        }

        uint256 expectedLength;
        {
            expectedLength = 2 + bytes(maybeWhitespace[0]).length + bytes(maybeWhitespace[1]).length
                + bytes(maybeWhitespace[2]).length + bytes(maybeWhitespace[3]).length + bytes(maybeWhitespace[4]).length;
        }

        string memory valueAString = asHex[0] ? uint256(values[0]).toHexString() : values[0].toStringSigned();
        string memory valueBString = asHex[1] ? uint256(values[1]).toHexString() : values[1].toStringSigned();
        string memory valueCString = asHex[2] ? uint256(values[2]).toHexString() : values[2].toStringSigned();
        string memory valueDString = asHex[3] ? uint256(values[3]).toHexString() : values[3].toStringSigned();

        {
            expectedLength += bytes(valueAString).length + bytes(valueBString).length + bytes(valueCString).length
            + bytes(valueDString).length;
        }

        string memory s;

        // This is chunked out to avoid stack overflows in the solidity compiler.
        {
            s = string.concat("<", maybeWhitespace[0], valueAString);

            s = string.concat(s, maybeWhitespace[1], valueBString);

            s = string.concat(s, maybeWhitespace[2], valueCString);

            s = string.concat(s, maybeWhitespace[3], valueDString);

            s = string.concat(s, maybeWhitespace[4], ">", suffix);
        }

        bytes32[] memory expectedValues = new bytes32[](4);
        for (uint256 i = 0; i < 4; i++) {
            expectedValues[i] =
                asHex[i] ? bytes32(uint256(values[i])) : Float.unwrap(LibDecimalFloat.packLossless(values[i], 0));
        }
        checkParsingOperandFromData(s, expectedValues, expectedLength);
    }

    /// More than 4 values is an error.
    function testParseOperandTooManyValues() external {
        vm.expectRevert(abi.encodeWithSelector(OperandValuesOverflow.selector, LibParseError.tagErrorOffset(9)));
        this.checkParsingOperandFromData("<1 2 3 4 5>", new bytes32[](0), 0);
    }

    /// Unclosed operand is an error.
    function testParseOperandUnclosed() external {
        vm.expectRevert(abi.encodeWithSelector(UnclosedOperand.selector, LibParseError.tagErrorOffset(8)));
        this.checkParsingOperandFromData("<1 2 3 4", new bytes32[](0), 0);
    }

    // Unexpected chars will be treated as unclosed operands.
    function testParseOperandUnexpectedChars() external {
        vm.expectRevert(abi.encodeWithSelector(UnclosedOperand.selector, LibParseError.tagErrorOffset(6)));
        this.checkParsingOperandFromData("<1 2 3;> 6", new bytes32[](0), 0);
    }

    // Two literals back-to-back without whitespace hit the yang-state
    // UnclosedOperand revert at line 111. After parsing `2`, yang is set,
    // then `"` is a valid literal head but yang prevents parsing it.
    function testParseOperandYangStateLiteralCollision() external {
        vm.expectRevert(abi.encodeWithSelector(UnclosedOperand.selector, LibParseError.tagErrorOffset(4)));
        this.checkParsingOperandFromData("<1 2\"hi\">", new bytes32[](0), 0);
    }
}
