// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpStringCount} from "../../../../../src/lib/op/string/LibOpStringCount.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "../../../../../src/interface/IInterpreterV4.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibFuzzString} from "test/lib/string/LibFuzzString.sol";
import {LibDecimalFloat, Float} from "rain-math-float-0.3.11/src/lib/LibDecimalFloat.sol";

contract LibOpStringCountTest is OpTest {
    function externalRun(StackItem input) external view returns (StackItem) {
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = input;
        return opRunOutputs(LibOperand.build(1, 1, 0), LibOpStringCount.run, inputs)[0];
    }

    function count(uint256 length) internal pure returns (bytes32) {
        //forge-lint: disable-next-line(unsafe-typecast)
        return Float.unwrap(LibDecimalFloat.packLossless(int256(length), 0));
    }

    /// Every operand declares 1 input and 1 output.
    function testOpStringCountIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpStringCount.integrity(state, operand);
        assertEq(calcInputs, 1);
        assertEq(calcOutputs, 1);
    }

    /// Run matches the reference on strings of up to 31 bytes.
    function testOpStringCountRun(bytes32 word, uint256 length) external view {
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = LibFuzzString.stackItem(LibFuzzString.leading(word, bound(length, 0, 31)));
        opReferenceCheck(
            opTestDefaultInterpreterState(),
            LibOperand.build(1, 1, 0),
            LibOpStringCount.referenceFn,
            LibOpStringCount.integrity,
            LibOpStringCount.run,
            inputs
        );
    }

    /// Inputs are untyped, so run must match the reference on every word.
    function testOpStringCountRunArbitraryWords(StackItem x) external view {
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = x;
        opReferenceCheck(
            opTestDefaultInterpreterState(),
            LibOperand.build(1, 1, 0),
            LibOpStringCount.referenceFn,
            LibOpStringCount.integrity,
            LibOpStringCount.run,
            inputs
        );
    }

    /// The output is the byte length as the Float `length e0`.
    function testOpStringCountRunIsFloatLength(bytes32 word, uint256 length) external view {
        length = bound(length, 0, 31);
        StackItem output = this.externalRun(LibFuzzString.stackItem(LibFuzzString.leading(word, length)));
        assertEq(StackItem.unwrap(output), count(length));
    }

    function testOpStringCountEvalTicker() external view {
        checkHappy("_: string-count(\"tMSTR\");", count(5), "");
    }

    function testOpStringCountEvalEmptyString() external view {
        checkHappy("_: string-count(\"\");", count(0), "");
    }

    /// 31 bytes is the longest an IntOrAString holds.
    function testOpStringCountEval31ByteString() external view {
        checkHappy("_: string-count(\"0123456789012345678901234567890\");", count(31), "");
    }

    /// The length is the low 5 bits; bits above the string and the truthy bits
    /// do not change it.
    function testOpStringCountEvalHexStrings() external view {
        checkHappy("_: string-count(0xe0);", count(0), "");
        checkHappy("_: string-count(0x61e1);", count(1), "");
        checkHappy("_: string-count(0xff61e1);", count(1), "");
        checkHappy("_: string-count(0x6101);", count(1), "");
        checkHappy(
            "_: string-count(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);", count(31), ""
        );
    }

    /// The count is a number to the rest of the language.
    function testOpStringCountEvalComparesAsNumber() external view {
        checkHappy("_: equal-to(string-count(\"abc\") 3);", bytes32(uint256(1)), "");
        checkHappyEq("_: add(string-count(\"abc\") 1.5);", LibDecimalFloat.packLossless(45, -1), "");
    }

    function testOpStringCountZeroInputs() external {
        checkBadInputs("_: string-count();", 0, 1, 0);
    }

    function testOpStringCountTwoInputs() external {
        checkBadInputs("_: string-count(\"a\" \"b\");", 2, 1, 2);
    }

    function testOpStringCountZeroOutputs() external {
        checkBadOutputs(": string-count(\"a\");", 1, 1, 0);
    }

    function testOpStringCountTwoOutputs() external {
        checkBadOutputs("_ _: string-count(\"a\");", 1, 1, 2);
    }

    function testOpStringCountEvalOperandDisallowed() external {
        checkUnhappyParse("_: string-count<0>(\"a\");", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
