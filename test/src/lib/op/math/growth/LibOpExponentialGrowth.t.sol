// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, IntegrityCheckState, OperandV2, InterpreterState, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpExponentialGrowth} from "../../../../../../src/lib/op/math/growth/LibOpExponentialGrowth.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

contract LibOpExponentialGrowthTest is OpTest {
    function beforeOpTestConstructor() internal virtual override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    /// Directly test the integrity logic of LibOpExponentialGrowth.
    /// Inputs are always 3, outputs are always 1.
    function testOpExponentialGrowthIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpExponentialGrowth.integrity(state, operand);
        assertEq(calcInputs, 3);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpExponentialGrowth.
    function testOpExponentialGrowthRun(
        int224 signedCoefficientA,
        int32 exponentA,
        int224 signedCoefficientR,
        int32 exponentR,
        int224 signedCoefficientT,
        int32 exponentT,
        uint16 operandData
    ) public view {
        signedCoefficientA = int224(bound(signedCoefficientA, 0, type(int8).max));
        exponentA = int32(bound(exponentA, -10, 10));
        Float a = LibDecimalFloat.packLossless(signedCoefficientA, exponentA);

        signedCoefficientR = int224(bound(signedCoefficientR, 0, type(int8).max));
        exponentR = int32(bound(exponentR, -10, 10));
        Float r = LibDecimalFloat.packLossless(signedCoefficientR, exponentR);

        signedCoefficientT = int224(bound(signedCoefficientT, 0, type(int8).max));
        exponentT = int32(bound(exponentT, -10, 5));
        Float t = LibDecimalFloat.packLossless(signedCoefficientT, exponentT);

        InterpreterState memory state = opTestDefaultInterpreterState();

        OperandV2 operand = LibOperand.build(3, 1, operandData);
        StackItem[] memory inputs = new StackItem[](3);
        inputs[0] = StackItem.wrap(Float.unwrap(a));
        inputs[1] = StackItem.wrap(Float.unwrap(r));
        inputs[2] = StackItem.wrap(Float.unwrap(t));

        opReferenceCheck(
            state,
            operand,
            LibOpExponentialGrowth.referenceFn,
            LibOpExponentialGrowth.integrity,
            LibOpExponentialGrowth.run,
            inputs
        );
    }

    /// Test the eval of `exponential-growth`.
    function testOpExponentialGrowthEval() external view {
        checkHappy("_: exponential-growth(0 0 0);", 0, "0 0 0");
        checkHappy("_: exponential-growth(0 0.1 0);", 0, "0 0.1 0");
        checkHappy("_: exponential-growth(0 0.1 1);", 0, "0 0.1 1");
        checkHappy("_: exponential-growth(1 0.1 0);", Float.unwrap(LibDecimalFloat.FLOAT_ONE), "1 0.1 0");
        checkHappy(
            "_: exponential-growth(1 0.1 1);", Float.unwrap(LibDecimalFloat.packLossless(1.1e67, -67)), "1 0.1 1"
        );
        // Exactly 1.21
        checkHappy(
            "_: exponential-growth(1 0.1 2);", Float.unwrap(LibDecimalFloat.packLossless(1.21e67, -67)), "1 0.1 2"
        );
        // Not exactly 1.26905870629
        checkHappy(
            "_: exponential-growth(1 0.1 2.5);",
            Float.unwrap(LibDecimalFloat.packLossless(1.26929e67, -67)),
            "1 0.1 2.5"
        );
        checkHappy("_: exponential-growth(1 0 2);", Float.unwrap(LibDecimalFloat.packLossless(1e3, -3)), "1 0 2");
        // Not exactly 1.0488088482
        checkHappy(
            "_: exponential-growth(1 0.1 0.5);", Float.unwrap(LibDecimalFloat.packLossless(1049, -3)), "1 0.1 0.5"
        );
        checkHappy("_: exponential-growth(2 0.1 0);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "2 0.1 0");
        checkHappy(
            "_: exponential-growth(2 0.1 1);", Float.unwrap(LibDecimalFloat.packLossless(2.2e66, -66)), "2 0.1 1"
        );
        checkHappy(
            "_: exponential-growth(2 0.1 2);", Float.unwrap(LibDecimalFloat.packLossless(2.42e66, -66)), "2 0.1 2"
        );

        /// 1.8181..
        checkHappy(
            "_: exponential-growth(2 0.1 -1);",
            Float.unwrap(
                LibDecimalFloat.packLossless(
                    1.818181818181818181818181818181818181818181818181818181818181818181e66, -66
                )
            ),
            "2 0.1 -1"
        );
    }

    function testOpExponentialGrowthEvalZeroInputs() external {
        checkBadInputs(": exponential-growth();", 0, 3, 0);
    }

    function testOpExponentialGrowthEvalOneInput() external {
        checkBadInputs("_: exponential-growth(1);", 1, 3, 1);
    }

    function testOpExponentialGrowthEvalTwoInputs() external {
        checkBadInputs("_: exponential-growth(1 0);", 2, 3, 2);
    }

    function testOpExponentialGrowthEvalFourInputs() external {
        checkBadInputs("_: exponential-growth(1 0 0 1);", 4, 3, 4);
    }

    function testOpExponentialGrowthEvalZeroOutputs() external {
        checkBadOutputs(": exponential-growth(1 0 0);", 3, 1, 0);
    }

    function testOpExponentialGrowthEvalTwoOutputs() external {
        checkBadOutputs("_ _: exponential-growth(1 0 0);", 3, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpExponentialGrowthEvalOperandDisallowed() external {
        checkUnhappyParse("_: exponential-growth<0>(1 0 0);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
