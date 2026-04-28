// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ExpectedOperand, UnclosedOperand} from "../../../../src/error/ErrParse.sol";
import {OperandTest} from "test/abstract/OperandTest.sol";
import {OperandOverflow} from "../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";

contract LibParseOperand8M1M1Test is OperandTest {
    /// Default is disallowed.
    function testOperand8M1M1Elided() external {
        checkParseError("_:e();", abi.encodeWithSelector(ExpectedOperand.selector));
        checkParseError("_:e<>();", abi.encodeWithSelector(ExpectedOperand.selector));
    }

    /// Single value can be provided and bits will default to zero.
    function testOperand8M1M1Single() external {
        checkOperandParse("_:e<1>();", hex"06100001");
        checkOperandParse("_:e<2>();", hex"06100002");
        checkOperandParse("_:e<3>();", hex"06100003");
        // Can parse up to max uint8.
        checkOperandParse("_:e<255>();", hex"061000ff");

        // Above uint8 max will overflow.
        checkParseError("_:e<256>();", abi.encodeWithSelector(OperandOverflow.selector));
    }

    /// Single value and one bit can be provided, other bit will default to zero.
    function testOperand8M1M1SingleBit() external {
        checkOperandParse("_:e<1 0>();", hex"06100001");
        checkOperandParse("_:e<1 1>();", hex"06100101");
        checkOperandParse("_:e<2 0>();", hex"06100002");
        checkOperandParse("_:e<2 1>();", hex"06100102");
        checkOperandParse("_:e<255 0>();", hex"061000ff");
        checkOperandParse("_:e<255 1>();", hex"061001ff");

        // Non binary bit will overflow.
        checkParseError("_:e<1 2>();", abi.encodeWithSelector(OperandOverflow.selector));
        checkParseError("_:e<1 3>();", abi.encodeWithSelector(OperandOverflow.selector));
        checkParseError("_:e<2 2>();", abi.encodeWithSelector(OperandOverflow.selector));
        checkParseError("_:e<255 2>();", abi.encodeWithSelector(OperandOverflow.selector));
    }

    /// Single value and two bits can be provided.
    function testOperand8M1M1SingleBitsPart1() external {
        checkOperandParse("_:e<1 0 0>();", hex"06100001");
        checkOperandParse("_:e<1 0 1>();", hex"06100201");
        checkOperandParse("_:e<1 1 0>();", hex"06100101");
        checkOperandParse("_:e<1 1 1>();", hex"06100301");
        checkOperandParse("_:e<2 0 0>();", hex"06100002");
        checkOperandParse("_:e<2 0 1>();", hex"06100202");
        checkOperandParse("_:e<2 1 0>();", hex"06100102");
        checkOperandParse("_:e<2 1 1>();", hex"06100302");
        checkOperandParse("_:e<255 0 0>();", hex"061000ff");
        checkOperandParse("_:e<255 0 1>();", hex"061002ff");
        checkOperandParse("_:e<255 1 0>();", hex"061001ff");
        checkOperandParse("_:e<255 1 1>();", hex"061003ff");

        // Non binary bit will overflow.
        checkParseError("_:e<1 0 2>();", abi.encodeWithSelector(OperandOverflow.selector));
        checkParseError("_:e<1 1 2>();", abi.encodeWithSelector(OperandOverflow.selector));
        checkParseError("_:e<1 2 0>();", abi.encodeWithSelector(OperandOverflow.selector));
        checkParseError("_:e<1 2 1>();", abi.encodeWithSelector(OperandOverflow.selector));
        checkParseError("_:e<1 2 2>();", abi.encodeWithSelector(OperandOverflow.selector));
        checkParseError("_:e<2 0 2>();", abi.encodeWithSelector(OperandOverflow.selector));
        checkParseError("_:e<2 1 2>();", abi.encodeWithSelector(OperandOverflow.selector));
        checkParseError("_:e<2 2 0>();", abi.encodeWithSelector(OperandOverflow.selector));
        checkParseError("_:e<2 2 1>();", abi.encodeWithSelector(OperandOverflow.selector));
        checkParseError("_:e<2 2 2>();", abi.encodeWithSelector(OperandOverflow.selector));
        checkParseError("_:e<255 0 2>();", abi.encodeWithSelector(OperandOverflow.selector));
        checkParseError("_:e<255 1 2>();", abi.encodeWithSelector(OperandOverflow.selector));
        checkParseError("_:e<255 2 0>();", abi.encodeWithSelector(OperandOverflow.selector));
        checkParseError("_:e<255 2 1>();", abi.encodeWithSelector(OperandOverflow.selector));
        checkParseError("_:e<255 2 2>();", abi.encodeWithSelector(OperandOverflow.selector));
    }

    /// Unclosed operand is disallowed.
    function testOperand8M1M1Unclosed() external {
        checkParseError("_:e<1 1();", abi.encodeWithSelector(UnclosedOperand.selector, LibParseError.tagErrorOffset(7)));
        checkParseError("_:e<1 0()", abi.encodeWithSelector(UnclosedOperand.selector, LibParseError.tagErrorOffset(7)));
        checkParseError("_:e<1 ", abi.encodeWithSelector(UnclosedOperand.selector, LibParseError.tagErrorOffset(6)));
        checkParseError("_:e<1", abi.encodeWithSelector(UnclosedOperand.selector, LibParseError.tagErrorOffset(5)));
        checkParseError("_:e<1 1", abi.encodeWithSelector(UnclosedOperand.selector, LibParseError.tagErrorOffset(7)));
        checkParseError("_:e<1 1 1", abi.encodeWithSelector(UnclosedOperand.selector, LibParseError.tagErrorOffset(9)));
    }

    /// Unopened operand is disallowed.
    function testOperand8M1M1Unopened() external {
        checkParseError("_:e>1 1>();", abi.encodeWithSelector(ExpectedOperand.selector));
    }
}
