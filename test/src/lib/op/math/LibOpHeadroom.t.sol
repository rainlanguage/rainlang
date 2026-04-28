// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, IntegrityCheckState, OperandV2, InterpreterState, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpHeadroom} from "../../../../../src/lib/op/math/LibOpHeadroom.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

contract LibOpHeadroomTest is OpTest {
    /// Directly test the integrity logic of LibOpHeadroom.
    /// Inputs is always 1, outputs is always 1.
    function testOpHeadroomIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpHeadroom.integrity(state, operand);
        assertEq(calcInputs, 1);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpHeadroom.
    function testOpHeadroomRun(Float a, uint16 operandData) public view {
        InterpreterState memory state = opTestDefaultInterpreterState();

        OperandV2 operand = LibOperand.build(1, 1, operandData);
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = StackItem.wrap(Float.unwrap(a));

        opReferenceCheck(state, operand, LibOpHeadroom.referenceFn, LibOpHeadroom.integrity, LibOpHeadroom.run, inputs);
    }

    /// Test the eval of `headroom`.
    function testOpHeadroomEval() external view {
        checkHappy("_: headroom(0);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "0");
        checkHappy("_: headroom(1);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "1");
        checkHappy("_: headroom(0.5);", Float.unwrap(LibDecimalFloat.packLossless(5e66, -67)), "0.5");
        checkHappy("_: headroom(2);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "2");
        checkHappy("_: headroom(3);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "3");
        checkHappy("_: headroom(3.8);", Float.unwrap(LibDecimalFloat.packLossless(2e66, -67)), "3.8");

        checkHappy("_: headroom(-1);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "-1");
        checkHappy("_: headroom(-0.5);", Float.unwrap(LibDecimalFloat.packLossless(0.5e1, -1)), "-0.5");
        checkHappy("_: headroom(-2);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "-2");
        checkHappy("_: headroom(-3);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "-3");
        checkHappy("_: headroom(-3.8);", Float.unwrap(LibDecimalFloat.packLossless(0.8e67, -67)), "-3.8");
    }

    /// Test the eval of `headroom` for bad inputs.
    function testOpHeadroomZeroInputs() external {
        checkBadInputs("_: headroom();", 0, 1, 0);
    }

    function testOpHeadroomTwoInputs() external {
        checkBadInputs("_: headroom(1 1);", 2, 1, 2);
    }

    function testOpHeadroomZeroOutputs() external {
        checkBadOutputs(": headroom(1);", 1, 1, 0);
    }

    function testOpHeadroomTwoOutputs() external {
        checkBadOutputs("_ _: headroom(1);", 1, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpHeadroomEvalOperandDisallowed() external {
        checkUnhappyParse("_: headroom<0>(1);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
