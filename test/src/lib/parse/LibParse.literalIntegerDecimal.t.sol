// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ParseTest} from "test/abstract/ParseTest.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";

import {LibParse, UnexpectedRHSChar, UnexpectedRightParen} from "../../../../src/lib/parse/LibParse.sol";
import {LibBytecode} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";
import {ParseDecimalOverflow} from "rain.string/error/ErrParse.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";

/// @title LibParseLiteralIntegerDecimalTest
/// @notice Tests parsing integer literal decimal values.
contract LibParseLiteralIntegerDecimalTest is ParseTest {
    using LibParse for ParseState;

    /// Check a single decimal literal. Should not revert and return length 1
    /// sources and constants.
    function testParseIntegerLiteralDecimal00() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_: 1;").parse();
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 1);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 0);
        assertEq(outputs, 1);

        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 op
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 output
            hex"01"
            // constant 0
            hex"01100000"
        );

        assertEq(constants.length, 1);
        assertEq(constants[0], Float.unwrap(LibDecimalFloat.packLossless(1, 0)));
    }

    /// Check 2 decimal literals. Should not revert and return one source and
    /// length 2 constants.
    function testParseIntegerLiteralDecimal01() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_ _: 10 25;").parse();
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 2);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 2);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 0);
        assertEq(outputs, 2);

        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 2 ops
            hex"02"
            // 2 stack allocation
            hex"02"
            // 0 inputs
            hex"00"
            // 2 outputs
            hex"02"
            // constant 0
            hex"01100000"
            // constant 1
            hex"01100001"
        );

        assertEq(constants.length, 2);
        assertEq(constants[0], Float.unwrap(LibDecimalFloat.packLossless(10, 0)));
        assertEq(constants[1], Float.unwrap(LibDecimalFloat.packLossless(25, 0)));
    }

    /// Check 3 decimal literals with 2 dupes. Should dedupe and respect ordering.
    function testParseIntegerLiteralDecimal02() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_ _ _: 11 233 11;").parse();
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 3);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 3);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 0);
        assertEq(outputs, 3);

        // Sources represents all 3 literals, but the dupe is deduped so that the
        // operands only reference the first instance of the duped constant.
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 3 ops
            hex"03"
            // 3 stack allocation
            hex"03"
            // 0 inputs
            hex"00"
            // 3 outputs
            hex"03"
            // constant 0
            hex"01100000"
            // constant 1
            hex"01100001"
            // constant 0
            hex"01100000"
        );
        assertEq(constants.length, 2);
        assertEq(constants[0], Float.unwrap(LibDecimalFloat.packLossless(11, 0)));
        assertEq(constants[1], Float.unwrap(LibDecimalFloat.packLossless(233, 0)));
    }

    /// Check that we can parse the max int128 value in decimal form.
    function testParseIntegerLiteralDecimalInt128Max() external view {
        (bytes memory bytecode, bytes32[] memory constants) =
            LibMetaFixture.newState("_: 170141183460469231731687303715884105727;").parse();
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 1);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 0);
        assertEq(outputs, 1);

        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 op
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 output
            hex"01"
            // constant 0
            hex"01100000"
        );

        assertEq(constants.length, 1);
        assertEq(constants[0], bytes32(uint256(int256(type(int128).max))));
    }

    /// Check that we can parse uint256 max int in decimal form with leading
    /// zeros.
    function testParseIntegerLiteralDecimalInt128MaxLeadingZeros() external view {
        (bytes memory bytecode, bytes32[] memory constants) =
            LibMetaFixture.newState("_: 000170141183460469231731687303715884105727;").parse();
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 1);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 0);
        assertEq(outputs, 1);

        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 op
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 output
            hex"01"
            // constant 0
            hex"01100000"
        );
        assertEq(constants.length, 1);
        assertEq(constants[0], bytes32(uint256(int256(type(int128).max))));
    }

    /// Check that decimal literals will revert if they overflow uint256.
    function testParseIntegerLiteralDecimalUint256OverflowSimple() external {
        vm.expectRevert(abi.encodeWithSelector(ParseDecimalOverflow.selector, LibParseError.tagErrorOffset(81)));
        (bytes memory bytecode, bytes32[] memory constants) =
            this.parseExternal("_: 115792089237316195423570985008687907853269984665640564039457584007913129639936e-18;");
        (bytecode);
        (constants);
    }

    /// Check that decimal literals will revert if they overflow uint256 with
    /// leading zeros.
    function testParseIntegerLiteralDecimalUint256OverflowLeadingZeros() external {
        vm.expectRevert(abi.encodeWithSelector(ParseDecimalOverflow.selector, LibParseError.tagErrorOffset(83)));
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal(
            "_: 00115792089237316195423570985008687907853269984665640564039457584007913129639936e-18;"
        );
        (bytecode);
        (constants);
    }

    // Check that decimal literals will revert if they overflow uint256 with
    // a non-one leading digit.
    function testParseIntegerLiteralDecimalUint256OverflowLeadingDigitBasic() external {
        vm.expectRevert(abi.encodeWithSelector(ParseDecimalOverflow.selector, LibParseError.tagErrorOffset(81)));
        (bytes memory bytecode, bytes32[] memory constants) =
            this.parseExternal("_: 215792089237316195423570985008687907853269984665640564039457584007913129639935e-18;");
        (bytecode);
        (constants);
    }

    /// Check that decimal literals will revert if they overflow uint256 with
    /// a non-one leading digit and leading zeros.
    function testParseIntegerLiteralDecimalUint256OverflowLeadingDigitLeadingZeros() external {
        vm.expectRevert(abi.encodeWithSelector(ParseDecimalOverflow.selector, LibParseError.tagErrorOffset(83)));
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal(
            "_: 00215792089237316195423570985008687907853269984665640564039457584007913129639935e-18;"
        );
        (bytecode);
        (constants);
    }

    /// Check that e notation works.
    function testParseIntegerLiteralDecimalENotation() external view {
        (bytes memory bytecode, bytes32[] memory constants) =
            LibMetaFixture.newState("_ _ _ _ _: 1e2 10e2 1e30 1e18 1001e15;").parse();
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 5);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 5);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 0);
        assertEq(outputs, 5);

        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 5 ops
            hex"05"
            // 5 stack allocation
            hex"05"
            // 0 inputs
            hex"00"
            // 5 outputs
            hex"05"
            // constant 0
            hex"01100000"
            // constant 1
            hex"01100001"
            // constant 2
            hex"01100002"
            // constant 3
            hex"01100003"
            // constant 4
            hex"01100004"
        );

        assertEq(constants.length, 5);
        assertEq(constants[0], Float.unwrap(LibDecimalFloat.packLossless(1, 2)));
        assertEq(constants[1], Float.unwrap(LibDecimalFloat.packLossless(10, 2)));
        assertEq(constants[2], Float.unwrap(LibDecimalFloat.packLossless(1, 30)));
        assertEq(constants[3], Float.unwrap(LibDecimalFloat.packLossless(1, 18)));
        assertEq(constants[4], Float.unwrap(LibDecimalFloat.packLossless(1001, 15)));
    }

    /// Check that decimals cause yang.
    function testParseIntegerLiteralDecimalYang() external {
        // The second e will happily be parsed up to by the internal bounds logic
        // but the parser will be in a state of yang, unable to receive the next
        // non-yin char.
        vm.expectRevert(abi.encodeWithSelector(UnexpectedRHSChar.selector, LibParseError.tagErrorOffset(5)));
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal("_:1e0e;");
        (bytecode);
        (constants);
    }

    /// Check that decimals cannot be used with parens as they are literals not
    /// words. This tests left paren.
    function testParseIntegerLiteralDecimalParensLeft() external {
        vm.expectRevert(abi.encodeWithSelector(UnexpectedRHSChar.selector, LibParseError.tagErrorOffset(3)));
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal("_:1(;");
        (bytecode);
        (constants);
    }

    /// Check that decimals cannot be used with parens as they are literals not
    /// words. This tests right paren.
    function testParseIntegerLiteralDecimalParensRight() external {
        vm.expectRevert(abi.encodeWithSelector(UnexpectedRightParen.selector, LibParseError.tagErrorOffset(3)));
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal("_:1);");
        (bytecode);
        (constants);
    }

    /// Check that decimals cannot be used with parens as they are literals not
    /// words. This tests both parens.
    function testParseIntegerLiteralDecimalParensBoth() external {
        vm.expectRevert(abi.encodeWithSelector(UnexpectedRHSChar.selector, LibParseError.tagErrorOffset(3)));
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal("_:1();");
        (bytecode);
        (constants);
    }
}
