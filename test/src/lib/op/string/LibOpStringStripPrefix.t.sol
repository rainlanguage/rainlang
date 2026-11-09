// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpStringStripPrefix} from "../../../../../src/lib/op/string/LibOpStringStripPrefix.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "../../../../../src/interface/IInterpreterV4.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibFuzzString} from "test/lib/string/LibFuzzString.sol";

contract LibOpStringStripPrefixTest is OpTest {
    function externalRun(bytes memory s, bytes memory p) external view returns (StackItem) {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = LibFuzzString.stackItem(s);
        inputs[1] = LibFuzzString.stackItem(p);
        return opRunOutputs(LibOperand.build(2, 1, 0), LibOpStringStripPrefix.run, inputs)[0];
    }

    function referenceCheck(StackItem s, StackItem p) internal view {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = s;
        inputs[1] = p;
        opReferenceCheck(
            opTestDefaultInterpreterState(),
            LibOperand.build(2, 1, 0),
            LibOpStringStripPrefix.referenceFn,
            LibOpStringStripPrefix.integrity,
            LibOpStringStripPrefix.run,
            inputs
        );
    }

    function str(bytes memory s) internal pure returns (bytes32) {
        return StackItem.unwrap(LibFuzzString.stackItem(s));
    }

    /// Every operand declares 2 inputs and 1 output.
    function testOpStringStripPrefixIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpStringStripPrefix.integrity(state, operand);
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Run matches the reference on independent strings of up to 31 bytes.
    function testOpStringStripPrefixRun(bytes32 sWord, uint256 sLength, bytes32 pWord, uint256 pLength)
        external
        view
    {
        referenceCheck(
            LibFuzzString.stackItem(LibFuzzString.leading(sWord, bound(sLength, 0, 31))),
            LibFuzzString.stackItem(LibFuzzString.leading(pWord, bound(pLength, 0, 31)))
        );
    }

    /// Inputs are untyped, so run must match the reference on every pair of
    /// words.
    function testOpStringStripPrefixRunArbitraryWords(StackItem s, StackItem p) external view {
        referenceCheck(s, p);
    }

    /// Stripping a leading slice leaves the rest of the string.
    function testOpStringStripPrefixRunLeadingSlice(bytes32 word, uint256 length, uint256 prefixLength)
        external
        view
    {
        length = bound(length, 0, 31);
        prefixLength = bound(prefixLength, 0, length);
        bytes memory s = LibFuzzString.leading(word, length);
        bytes memory p = LibFuzzString.leading(word, prefixLength);
        referenceCheck(LibFuzzString.stackItem(s), LibFuzzString.stackItem(p));
        bytes memory rest = LibFuzzString.leading(bytes32(uint256(word) << (8 * prefixLength)), length - prefixLength);
        assertEq(StackItem.unwrap(this.externalRun(s, p)), str(rest));
    }

    /// A leading slice with any one byte changed is not a prefix, so the
    /// string is unchanged.
    function testOpStringStripPrefixRunMismatchedByte(
        bytes32 word,
        uint256 length,
        uint256 prefixLength,
        uint256 index,
        uint8 flip
    ) external view {
        length = bound(length, 1, 31);
        prefixLength = bound(prefixLength, 1, length);
        bytes memory s = LibFuzzString.leading(word, length);
        bytes memory p = LibFuzzString.leading(word, prefixLength);
        index = bound(index, 0, prefixLength - 1);
        p[index] = p[index] ^ bytes1(uint8(bound(flip, 1, 0xff)));
        referenceCheck(LibFuzzString.stackItem(s), LibFuzzString.stackItem(p));
        assertEq(StackItem.unwrap(this.externalRun(s, p)), str(s));
    }

    /// A prefix longer than the string leaves the string unchanged, even when
    /// the string is a prefix of it.
    function testOpStringStripPrefixRunLongerPrefix(bytes32 word, uint256 length, uint256 prefixLength)
        external
        view
    {
        length = bound(length, 0, 30);
        bytes memory s = LibFuzzString.leading(word, length);
        bytes memory p = LibFuzzString.leading(word, bound(prefixLength, length + 1, 31));
        referenceCheck(LibFuzzString.stackItem(s), LibFuzzString.stackItem(p));
        assertEq(StackItem.unwrap(this.externalRun(s, p)), str(s));
    }

    /// A vault symbol is its ticker behind a fixed `t`.
    function testOpStringStripPrefixEvalTickerPrefix() external view {
        checkHappy("_: string-strip-prefix(\"tMSTR\" \"t\");", str("MSTR"), "");
        checkHappy("_: binary-equal-to(string-strip-prefix(\"tMSTR\" \"t\") \"MSTR\");", bytes32(uint256(1)), "");
        checkHappy("_: string-strip-prefix(\"MSTR\" \"t\");", str("MSTR"), "");
        checkHappy("_: string-strip-prefix(\"TMSTR\" \"t\");", str("TMSTR"), "");
    }

    /// The prefix is stripped once.
    function testOpStringStripPrefixEvalStripsOnce() external view {
        checkHappy("_: string-strip-prefix(\"ttMSTR\" \"t\");", str("tMSTR"), "");
    }

    /// The first input is the string and the second the prefix.
    function testOpStringStripPrefixEvalInputOrder() external view {
        checkHappy("_: string-strip-prefix(\"t\" \"tMSTR\");", str("t"), "");
    }

    function testOpStringStripPrefixEvalEmptyPrefix() external view {
        checkHappy("_: string-strip-prefix(\"abc\" \"\");", str("abc"), "");
        checkHappy("_: string-strip-prefix(\"\" \"\");", str(""), "");
    }

    function testOpStringStripPrefixEvalEmptyString() external view {
        checkHappy("_: string-strip-prefix(\"\" \"a\");", str(""), "");
    }

    /// Stripping the whole string leaves the empty string.
    function testOpStringStripPrefixEvalWholeString() external view {
        checkHappy("_: string-strip-prefix(\"abc\" \"abc\");", str(""), "");
        checkHappy("_: string-strip-prefix(\"abc\" \"abd\");", str("abc"), "");
    }

    /// 31 bytes is the longest an IntOrAString holds.
    function testOpStringStripPrefixEval31ByteString() external view {
        checkHappy(
            "_: string-strip-prefix(\"0123456789012345678901234567890\" \"0123456789012345678901234567890\");",
            str(""),
            ""
        );
        checkHappy(
            "_: string-strip-prefix(\"0123456789012345678901234567890\" \"0\");",
            str("123456789012345678901234567890"),
            ""
        );
        checkHappy(
            "_: string-strip-prefix(\"0123456789012345678901234567890\" \"0123456789012345678901234567891\");",
            str("0123456789012345678901234567890"),
            ""
        );
    }

    /// Bits above the string and the truthy bits are not part of the string,
    /// and the output is canonical whether or not the prefix is stripped.
    function testOpStringStripPrefixEvalHexStrings() external view {
        checkHappy("_: string-strip-prefix(0xff7461e2 \"t\");", str("a"), "");
        checkHappy("_: string-strip-prefix(0xff7461e2 \"a\");", str("ta"), "");
        checkHappy("_: string-strip-prefix(\"ta\" 0xff74e1);", str("a"), "");
        checkHappy("_: string-strip-prefix(0x746102 0x7401);", str("a"), "");
    }

    function testOpStringStripPrefixZeroInputs() external {
        checkBadInputs("_: string-strip-prefix();", 0, 2, 0);
    }

    function testOpStringStripPrefixOneInput() external {
        checkBadInputs("_: string-strip-prefix(\"a\");", 1, 2, 1);
    }

    function testOpStringStripPrefixThreeInputs() external {
        checkBadInputs("_: string-strip-prefix(\"a\" \"b\" \"c\");", 3, 2, 3);
    }

    function testOpStringStripPrefixZeroOutputs() external {
        checkBadOutputs(": string-strip-prefix(\"a\" \"b\");", 2, 1, 0);
    }

    function testOpStringStripPrefixTwoOutputs() external {
        checkBadOutputs("_ _: string-strip-prefix(\"a\" \"b\");", 2, 1, 2);
    }

    function testOpStringStripPrefixEvalOperandDisallowed() external {
        checkUnhappyParse(
            "_: string-strip-prefix<0>(\"a\" \"b\");", abi.encodeWithSelector(UnexpectedOperand.selector)
        );
    }
}
