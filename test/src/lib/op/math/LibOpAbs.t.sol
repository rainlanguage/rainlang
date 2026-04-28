// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, IntegrityCheckState, OperandV2, InterpreterState, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpAbs} from "../../../../../src/lib/op/math/LibOpAbs.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

contract LibOpAbsTest is OpTest {
    /// Directly test the integrity logic of LibOpAbs.
    /// Inputs are always 1, outputs are always 1.
    function testOpAbsIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpAbs.integrity(state, operand);
        assertEq(calcInputs, 1);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpAbs.
    function testOpAbsRun(Float a, uint16 operandData) public view {
        InterpreterState memory state = opTestDefaultInterpreterState();

        (int256 signedCoefficient, int256 exponent) = LibDecimalFloat.unpack(a);
        vm.assume(signedCoefficient > type(int224).min);
        (exponent);

        OperandV2 operand = LibOperand.build(1, 1, operandData);
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = StackItem.wrap(Float.unwrap(a));

        opReferenceCheck(state, operand, LibOpAbs.referenceFn, LibOpAbs.integrity, LibOpAbs.run, inputs);
    }

    /// Test the eval of `abs`.
    function testOpAbsEval() external view {
        checkHappy("_: abs(0);", 0, "0");
        checkHappy("_: abs(1);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "1");
        checkHappy("_: abs(-1);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "1");
        checkHappy("_: abs(0.5);", Float.unwrap(LibDecimalFloat.packLossless(0.5e1, -1)), "0.5");
        checkHappy("_: abs(-0.5);", Float.unwrap(LibDecimalFloat.packLossless(0.5e1, -1)), "-0.5");
        checkHappy("_: abs(2);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "2");
        checkHappy("_: abs(-2);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "-2");
    }

    /// Test the eval of `abs` for bad inputs.
    function testOpAbsZeroInputs() external {
        checkBadInputs("_: abs();", 0, 1, 0);
    }

    function testOpAbsTwoInputs() external {
        checkBadInputs("_: abs(1 1);", 2, 1, 2);
    }

    function testOpAbsZeroOutputs() external {
        checkBadOutputs(": abs(1);", 1, 1, 0);
    }

    function testOpAbsTwoOutputs() external {
        checkBadOutputs("_ _: abs(1);", 1, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpAbsEvalOperandDisallowed() external {
        checkUnhappyParse("_: abs<0>(1);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
