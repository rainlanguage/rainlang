// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibBytecode} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";
import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {IntOrAString, LibIntOrAString} from "rain.intorastring/lib/LibIntOrAString.sol";
import {StringTooLong, UnclosedStringLiteral} from "../../../../src/error/ErrParse.sol";
import {LibConformString} from "rain.string/lib/mut/LibConformString.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";

/// @title LibParseLiteralStringTest
/// @notice Tests for parsing string literals.
contract LibParseLiteralStringTest is Test {
    using LibParse for ParseState;

    /// External parse function to allow us to assert reverts.
    function externalParse(string memory str) external view returns (bytes memory, bytes32[] memory) {
        return LibMetaFixture.newState(str).parse();
    }

    /// Check an empty string literal. Should not revert and return length 1
    /// sources and constants.
    function testParseStringLiteralEmpty() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_: \"\";").parse();
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 1);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 0);
        assertEq(outputs, 1);

        assertEq(constants.length, 1);
        assertEq(constants[0], bytes32(IntOrAString.unwrap(LibIntOrAString.fromStringV3(""))));
    }

    /// Check a simple string `"a"` literal. Should not revert and return
    /// length 1 sources and constants.
    function testParseStringLiteralSimple() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_: \"a\";").parse();
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 1);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 0);
        assertEq(outputs, 1);

        assertEq(constants.length, 1);
        assertEq(constants[0], bytes32(IntOrAString.unwrap(LibIntOrAString.fromStringV3("a"))));
    }

    /// Any ASCII printable string shorter than 32 bytes should be parsed
    /// correctly.
    /// forge-config: default.fuzz.runs = 100
    function testParseStringLiteralShortASCII(string memory str) external view {
        vm.assume(bytes(str).length < 0x20);
        LibConformString.conformValidPrintableStringContent(str);

        (bytes memory bytecode, bytes32[] memory constants) =
            LibMetaFixture.newState(string.concat("_: \"", str, "\";")).parse();
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 1);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 0);
        assertEq(outputs, 1);

        assertEq(constants.length, 1);
        assertEq(constants[0], bytes32(IntOrAString.unwrap(LibIntOrAString.fromStringV3(str))));
    }

    /// Can parse 2 valid strings.
    /// forge-config: default.fuzz.runs = 100
    function testParseStringLiteralTwo(string memory strA, string memory strB) external view {
        vm.assume(bytes(strA).length < 0x20);
        LibConformString.conformValidPrintableStringContent(strA);
        vm.assume(bytes(strB).length < 0x20);
        LibConformString.conformValidPrintableStringContent(strB);
        vm.assume(keccak256(bytes(strA)) != keccak256(bytes(strB)));

        (bytes memory bytecode, bytes32[] memory constants) =
            LibMetaFixture.newState(string.concat("_ _: \"", strA, "\"\"", strB, "\";")).parse();
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 2);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 2);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 0);
        assertEq(outputs, 2);

        assertEq(constants.length, 2);
        assertEq(constants[0], bytes32(IntOrAString.unwrap(LibIntOrAString.fromStringV3(strA))));
        assertEq(constants[1], bytes32(IntOrAString.unwrap(LibIntOrAString.fromStringV3(strB))));
    }

    /// Valid ASCII printable strings 32 bytes or longer should error.
    /// forge-config: default.fuzz.runs = 100
    function testParseStringLiteralLongASCII(string memory str) external {
        vm.assume(bytes(str).length >= 0x20);
        LibConformString.conformValidPrintableStringContent(str);

        vm.expectRevert(abi.encodeWithSelector(StringTooLong.selector, LibParseError.tagErrorOffset(3)));
        (bytes memory bytecode, bytes32[] memory constants) = this.externalParse(string.concat("_: \"", str, "\";"));
        (bytecode, constants);
    }

    /// Invalid chars beyond the 31 byte valid range will not be parsed. Instead
    /// a `StringTooLong` error will be thrown.
    /// forge-config: default.fuzz.runs = 100
    function testParseStringLiteralInvalidCharAfter(string memory strA, string memory strB) external {
        vm.assume(bytes(strA).length >= 0x20);
        LibConformString.conformValidPrintableStringContent(strA);
        assembly ("memory-safe") {
            // Force truncate the string to 32 bytes.
            mstore(strA, 0x20)
        }

        vm.expectRevert(abi.encodeWithSelector(StringTooLong.selector, LibParseError.tagErrorOffset(3)));
        (bytes memory bytecode, bytes32[] memory constants) =
            this.externalParse(string.concat("_: \"", strA, strB, "\";"));
        (bytecode, constants);
    }

    /// Invalid chars anywhere in the parsed string will cause an unclosed
    /// string literal error.
    /// forge-config: default.fuzz.runs = 100
    function testParseStringLiteralInvalidCharWithin(string memory str, uint256 badIndex) external {
        vm.assume(bytes(str).length > 0);
        LibConformString.conformValidPrintableStringContent(str);
        badIndex = bound(badIndex, 0, (bytes(str).length > 0x1F ? 0x1F : bytes(str).length) - 1);

        LibConformString.corruptSingleChar(str, badIndex);

        vm.expectRevert(
            abi.encodeWithSelector(UnclosedStringLiteral.selector, LibParseError.tagErrorOffset(4 + badIndex))
        );
        (bytes memory bytecode, bytes32[] memory constants) = this.externalParse(string.concat("_: \"", str, "\";"));
        (bytecode, constants);
    }
}
