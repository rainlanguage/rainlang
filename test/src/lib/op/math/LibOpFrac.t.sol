// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, IntegrityCheckState, OperandV2, InterpreterState, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpFrac} from "../../../../../src/lib/op/math/LibOpFrac.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

contract LibOpFracTest is OpTest {
    /// Directly test the integrity logic of LibOpFrac.
    /// Inputs are always 1, outputs are always 1.
    function testOpFracIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpFrac.integrity(state, operand);
        assertEq(calcInputs, 1);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpFrac.
    function testOpFracRun(Float a, uint16 operandData) public view {
        InterpreterState memory state = opTestDefaultInterpreterState();

        OperandV2 operand = LibOperand.build(1, 1, operandData);
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = StackItem.wrap(Float.unwrap(a));

        opReferenceCheck(state, operand, LibOpFrac.referenceFn, LibOpFrac.integrity, LibOpFrac.run, inputs);
    }

    /// Test the eval of `frac`.
    function testOpFracEval() external view {
        checkHappy("_: frac(0);", 0, "0");
        checkHappy("_: frac(1);", 0, "1");
        checkHappy("_: frac(0.5);", Float.unwrap(LibDecimalFloat.packLossless(0.5e1, -1)), "0.5");
        checkHappy("_: frac(2);", 0, "2");
        checkHappy("_: frac(3);", 0, "3");
        checkHappy("_: frac(3.8);", Float.unwrap(LibDecimalFloat.packLossless(0.8e1, -1)), "3.8");
        checkHappy("_: frac(-0.5);", Float.unwrap(LibDecimalFloat.packLossless(-0.5e1, -1)), "-0.5");
        checkHappy("_: frac(1.5e10);", Float.unwrap(LibDecimalFloat.packLossless(0, 9)), "1.5e10");
    }

    /// Test the eval of `frac` for bad inputs.
    function testOpFracZeroInputs() external {
        checkBadInputs("_: frac();", 0, 1, 0);
    }

    function testOpFracTwoInputs() external {
        checkBadInputs("_: frac(1 1);", 2, 1, 2);
    }

    function testOpFracZeroOutputs() external {
        checkBadOutputs(": frac(1);", 1, 1, 0);
    }

    function testOpFracTwoOutputs() external {
        checkBadOutputs("_ _: frac(1);", 1, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpFracEvalOperandDisallowed() external {
        checkUnhappyParse("_: frac<0>(1);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
