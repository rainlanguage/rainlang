// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, IntegrityCheckState, OperandV2, InterpreterState, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpPower} from "../../../../../src/lib/op/math/LibOpPower.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {PowNegativeBase} from "rain.math.float/error/ErrDecimalFloat.sol";

contract LibOpPowerTest is OpTest {
    function beforeOpTestConstructor() internal virtual override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    /// Directly test the integrity logic of LibOpPower.
    /// Inputs are always 2, outputs are always 1.
    function testOpPowIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpPower.integrity(state, operand);
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpPower.
    function testOpPowRun(int224 signedCoefficientA, int32 exponentA, int224 signedCoefficientB, int32 exponentB)
        public
        view
    {
        signedCoefficientA = int224(bound(signedCoefficientA, 0, 10000));
        exponentA = int32(bound(exponentA, -100, 10));
        Float a = LibDecimalFloat.packLossless(signedCoefficientA, exponentA);
        signedCoefficientB = int224(bound(signedCoefficientB, 0, 10000));
        exponentB = int32(bound(exponentB, -100, 1));
        Float b = LibDecimalFloat.packLossless(signedCoefficientB, exponentB);
        InterpreterState memory state = opTestDefaultInterpreterState();

        OperandV2 operand = LibOperand.build(2, 1, 0);
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(Float.unwrap(a));
        inputs[1] = StackItem.wrap(Float.unwrap(b));

        opReferenceCheck(state, operand, LibOpPower.referenceFn, LibOpPower.integrity, LibOpPower.run, inputs);
    }

    /// Test the eval of `power`.
    function testOpPowEval() external view {
        // 0 ^ 0
        checkHappy("_: power(0 0);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "0 0");
        // 0 ^ 1
        checkHappy("_: power(0 1);", 0, "0 1");
        // 0 ^ 2
        checkHappy("_: power(0 2);", 0, "0 2");
        // 1 ^ 0
        checkHappy("_: power(1 0);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "1 0");
        // 1 ^ 1
        checkHappy("_: power(1 1);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "1 1");
        // 1 ^ 2
        checkHappy("_: power(1 2);", Float.unwrap(LibDecimalFloat.packLossless(1e3, -3)), "1 2");
        // 2 ^ 2
        checkHappy("_: power(2 2);", Float.unwrap(LibDecimalFloat.packLossless(4000, -3)), "2 2");
        // 2 ^ 3
        checkHappy("_: power(2 3);", Float.unwrap(LibDecimalFloat.packLossless(8000, -3)), "2 3");
        // 2 ^ 4
        checkHappy("_: power(2 4);", Float.unwrap(LibDecimalFloat.packLossless(16000, -3)), "2 4");
        // sqrt 4 = 2
        checkHappy("_: power(4 0.5);", Float.unwrap(LibDecimalFloat.packLossless(2e3, -3)), "4 0.5");
        // -1 ^ 0 = 1
        checkHappy("_: power(-1 0);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "-1 0");
    }

    function testOpPowNegativeBaseError() external {
        // Negative base with positive exponent.
        checkUnhappy("_: power(-1 2);", abi.encodeWithSelector(PowNegativeBase.selector, -1, 0));
        // Negative base with negative exponent.
        checkUnhappy("_: power(-1 -2);", abi.encodeWithSelector(PowNegativeBase.selector, -1, 0));
    }

    /// Test the eval of `power` for bad inputs.
    function testOpPowEvalOneInput() external {
        checkBadInputs("_: power(1);", 1, 2, 1);
    }

    function testOpPowThreeInputs() external {
        checkBadInputs("_: power(1 1 1);", 3, 2, 3);
    }

    function testOpPowZeroOutputs() external {
        checkBadOutputs(": power(1 1);", 2, 1, 0);
    }

    function testOpPowTwoOutputs() external {
        checkBadOutputs("_ _: power(1 1);", 2, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpPowEvalOperandDisallowed() external {
        checkUnhappyParse("_: power<0>(1 1);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
