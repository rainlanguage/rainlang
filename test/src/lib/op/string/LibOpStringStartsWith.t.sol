// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpStringStartsWith} from "../../../../../src/lib/op/string/LibOpStringStartsWith.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "../../../../../src/interface/IInterpreterV4.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibFuzzString} from "test/lib/string/LibFuzzString.sol";

contract LibOpStringStartsWithTest is OpTest {
    function externalRun(bytes memory s, bytes memory p) external view returns (StackItem) {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = LibFuzzString.stackItem(s);
        inputs[1] = LibFuzzString.stackItem(p);
        return opRunOutputs(LibOperand.build(2, 1, 0), LibOpStringStartsWith.run, inputs)[0];
    }

    function referenceCheck(StackItem s, StackItem p) internal view {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = s;
        inputs[1] = p;
        opReferenceCheck(
            opTestDefaultInterpreterState(),
            LibOperand.build(2, 1, 0),
            LibOpStringStartsWith.referenceFn,
            LibOpStringStartsWith.integrity,
            LibOpStringStartsWith.run,
            inputs
        );
    }

    /// Every operand declares 2 inputs and 1 output.
    function testOpStringStartsWithIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpStringStartsWith.integrity(state, operand);
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Run matches the reference on independent strings of up to 31 bytes.
    function testOpStringStartsWithRun(bytes32 sWord, uint256 sLength, bytes32 pWord, uint256 pLength)
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
    function testOpStringStartsWithRunArbitraryWords(StackItem s, StackItem p) external view {
        referenceCheck(s, p);
    }

    /// Every leading slice of a string, the empty and the whole string
    /// included, is a prefix of it.
    function testOpStringStartsWithRunLeadingSlice(bytes32 word, uint256 length, uint256 prefixLength)
        external
        view
    {
        length = bound(length, 0, 31);
        bytes memory s = LibFuzzString.leading(word, length);
        bytes memory p = LibFuzzString.leading(word, bound(prefixLength, 0, length));
        referenceCheck(LibFuzzString.stackItem(s), LibFuzzString.stackItem(p));
        assertEq(StackItem.unwrap(this.externalRun(s, p)), bytes32(uint256(1)));
    }

    /// A leading slice with any one byte changed is not a prefix.
    function testOpStringStartsWithRunMismatchedByte(
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
        assertEq(StackItem.unwrap(this.externalRun(s, p)), bytes32(0));
    }

    /// A prefix longer than the string is not a prefix, even when the string
    /// is a prefix of it.
    function testOpStringStartsWithRunLongerPrefix(bytes32 word, uint256 length, uint256 prefixLength)
        external
        view
    {
        length = bound(length, 0, 30);
        bytes memory s = LibFuzzString.leading(word, length);
        bytes memory p = LibFuzzString.leading(word, bound(prefixLength, length + 1, 31));
        referenceCheck(LibFuzzString.stackItem(s), LibFuzzString.stackItem(p));
        assertEq(StackItem.unwrap(this.externalRun(s, p)), bytes32(0));
    }

    /// A vault symbol is its ticker behind a fixed `t`.
    function testOpStringStartsWithEvalTickerPrefix() external view {
        checkHappy("_: string-starts-with(\"tMSTR\" \"t\");", bytes32(uint256(1)), "");
        checkHappy("_: string-starts-with(\"MSTR\" \"t\");", 0, "");
        checkHappy("_: string-starts-with(\"TMSTR\" \"t\");", 0, "");
    }

    /// The first input is the string and the second the prefix.
    function testOpStringStartsWithEvalInputOrder() external view {
        checkHappy("_: string-starts-with(\"t\" \"tMSTR\");", 0, "");
    }

    function testOpStringStartsWithEvalEmptyPrefix() external view {
        checkHappy("_: string-starts-with(\"abc\" \"\");", bytes32(uint256(1)), "");
        checkHappy("_: string-starts-with(\"\" \"\");", bytes32(uint256(1)), "");
    }

    function testOpStringStartsWithEvalEmptyString() external view {
        checkHappy("_: string-starts-with(\"\" \"a\");", 0, "");
    }

    function testOpStringStartsWithEvalWholeString() external view {
        checkHappy("_: string-starts-with(\"abc\" \"abc\");", bytes32(uint256(1)), "");
        checkHappy("_: string-starts-with(\"abc\" \"abd\");", 0, "");
    }

    /// 31 bytes is the longest an IntOrAString holds.
    function testOpStringStartsWithEval31ByteString() external view {
        checkHappy(
            "_: string-starts-with(\"0123456789012345678901234567890\" \"0123456789012345678901234567890\");",
            bytes32(uint256(1)),
            ""
        );
        checkHappy(
            "_: string-starts-with(\"0123456789012345678901234567890\" \"012345678901234567890123456789\");",
            bytes32(uint256(1)),
            ""
        );
        checkHappy(
            "_: string-starts-with(\"0123456789012345678901234567890\" \"0123456789012345678901234567891\");", 0, ""
        );
    }

    /// Bits above the string and the truthy bits are not part of the string.
    function testOpStringStartsWithEvalHexStrings() external view {
        checkHappy("_: string-starts-with(0xff7461e2 \"t\");", bytes32(uint256(1)), "");
        checkHappy("_: string-starts-with(\"ta\" 0xff74e1);", bytes32(uint256(1)), "");
        checkHappy("_: string-starts-with(0x746102 0x7401);", bytes32(uint256(1)), "");
    }

    function testOpStringStartsWithZeroInputs() external {
        checkBadInputs("_: string-starts-with();", 0, 2, 0);
    }

    function testOpStringStartsWithOneInput() external {
        checkBadInputs("_: string-starts-with(\"a\");", 1, 2, 1);
    }

    function testOpStringStartsWithThreeInputs() external {
        checkBadInputs("_: string-starts-with(\"a\" \"b\" \"c\");", 3, 2, 3);
    }

    function testOpStringStartsWithZeroOutputs() external {
        checkBadOutputs(": string-starts-with(\"a\" \"b\");", 2, 1, 0);
    }

    function testOpStringStartsWithTwoOutputs() external {
        checkBadOutputs("_ _: string-starts-with(\"a\" \"b\");", 2, 1, 2);
    }

    function testOpStringStartsWithEvalOperandDisallowed() external {
        checkUnhappyParse(
            "_: string-starts-with<0>(\"a\" \"b\");", abi.encodeWithSelector(UnexpectedOperand.selector)
        );
    }
}
