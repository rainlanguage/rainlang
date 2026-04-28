// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, IntegrityCheckState, OperandV2, InterpreterState, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpExp} from "../../../../../src/lib/op/math/LibOpExp.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

contract LibOpExpTest is OpTest {
    function beforeOpTestConstructor() internal virtual override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    /// Directly test the integrity logic of LibOpExp.
    /// Inputs are always 1, outputs are always 1.
    function testOpExpIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpExp.integrity(state, operand);
        assertEq(calcInputs, 1);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpExp.
    function testOpExpRun(int224 signedCoefficientA, int32 exponentA, uint16 operandData) public view {
        signedCoefficientA = int224(bound(signedCoefficientA, 0, 10000));
        exponentA = int32(bound(exponentA, -10, 5));

        InterpreterState memory state = opTestDefaultInterpreterState();
        OperandV2 operand = LibOperand.build(1, 1, operandData);

        Float a = LibDecimalFloat.packLossless(signedCoefficientA, exponentA);

        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = StackItem.wrap(Float.unwrap(a));

        opReferenceCheck(state, operand, LibOpExp.referenceFn, LibOpExp.integrity, LibOpExp.run, inputs);
    }

    /// Test the eval of `exp`.
    function testOpExpEvalExample() external view {
        checkHappy("_: exp(0);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "e^0");
        checkHappy(
            "_: exp(1);",
            Float.unwrap(
                LibDecimalFloat.packLossless(
                    2.718281828459045235360287471352662497757247093699959574966967627724e66, -66
                )
            ),
            "e^1"
        );
        checkHappy(
            "_: exp(0.5);",
            Float.unwrap(
                LibDecimalFloat.packLossless(
                    1.648640914229522617680143735676331248878623546849979787483483813862e66, -66
                )
            ),
            "e^0.5"
        );
        checkHappy(
            "_: exp(2);",
            Float.unwrap(
                LibDecimalFloat.packLossless(
                    7.389056098930650227230427460575007813180315570551847324087127822522e66, -66
                )
            ),
            "e^2"
        );
        checkHappy(
            "_: exp(3);",
            Float.unwrap(
                LibDecimalFloat.packLossless(
                    20.08553692318766774092852965458171789698790783855415014437893422969e65, -65
                )
            ),
            "e^3"
        );
    }

    /// Test exp with negative input. exp(-1) = 1/e ≈ 0.3678794...
    function testOpExpEvalNegativeInput() external view {
        (Float expected,) =
            LibDecimalFloat.packLossy(3678794411714423215955237701614608674458111310317678345078368016974, -67);
        checkHappy("_: exp(-1);", Float.unwrap(expected), "e^(-1)");
    }

    /// Test the eval of `exp` for bad inputs.
    function testOpExpEvalZeroInputs() external {
        checkBadInputs("_: exp();", 0, 1, 0);
    }

    function testOpExpEvalTwoInputs() external {
        checkBadInputs("_: exp(1 1);", 2, 1, 2);
    }

    function testOpExpZeroOutputs() external {
        checkBadOutputs(": exp(1);", 1, 1, 0);
    }

    function testOpExpTwoOutputs() external {
        checkBadOutputs("_ _: exp(1);", 1, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpExpEvalOperandDisallowed() external {
        checkUnhappyParse("_: exp<0>(1);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
