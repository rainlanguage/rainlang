// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, IntegrityCheckState, OperandV2, InterpreterState, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpExp2} from "../../../../../src/lib/op/math/LibOpExp2.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

contract LibOpExp2Test is OpTest {
    function beforeOpTestConstructor() internal virtual override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    /// Directly test the integrity logic of LibOpExp2.
    /// Inputs are always 1, outputs are always 1.
    function testOpExp2Integrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpExp2.integrity(state, operand);
        assertEq(calcInputs, 1);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpExp2.
    function testOpExp2Run(int224 signedCoefficientA, int32 exponentA, uint16 operandData) public view {
        signedCoefficientA = int224(bound(signedCoefficientA, 0, 10000));
        exponentA = int32(bound(exponentA, -10, 5));
        InterpreterState memory state = opTestDefaultInterpreterState();
        Float a = LibDecimalFloat.packLossless(signedCoefficientA, exponentA);

        OperandV2 operand = LibOperand.build(1, 1, operandData);
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = StackItem.wrap(Float.unwrap(a));

        opReferenceCheck(state, operand, LibOpExp2.referenceFn, LibOpExp2.integrity, LibOpExp2.run, inputs);
    }

    /// Test the eval of `exp2`.
    function testOpExp2EvalExample() external view {
        checkHappy("_: exp2(0);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "2^0");
        checkHappy("_: exp2(1);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "2^1");
        checkHappy("_: exp2(0.5);", Float.unwrap(LibDecimalFloat.packLossless(1415, -3)), "2^0.5");
        checkHappy("_: exp2(2);", Float.unwrap(LibDecimalFloat.packLossless(4000, -3)), "2^2");
        checkHappy("_: exp2(3);", Float.unwrap(LibDecimalFloat.packLossless(8000, -3)), "2^3");
    }

    /// Test exp2 with negative input. exp2(-1) = 0.5.
    function testOpExp2EvalNegativeInput() external view {
        (Float expected,) =
            LibDecimalFloat.packLossy(5000000000000000000000000000000000000000000000000000000000000000000, -67);
        checkHappy("_: exp2(-1);", Float.unwrap(expected), "2^(-1)");
    }

    /// Test the eval of `exp2` for bad inputs.
    function testOpExp2EvalBad() external {
        checkBadInputs("_: exp2();", 0, 1, 0);
        checkBadInputs("_: exp2(1 1);", 2, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpExp2EvalOperandDisallowed() external {
        checkUnhappyParse("_: exp2<0>(1);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }

    function testOpExp2ZeroOutputs() external {
        checkBadOutputs(": exp2(1);", 1, 1, 0);
    }

    function testOpExp2TwoOutputs() external {
        checkBadOutputs("_ _: exp2(1);", 1, 1, 2);
    }
}
