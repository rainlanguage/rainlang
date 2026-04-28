// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {LibOpMax} from "../../../../../src/lib/op/math/LibOpMax.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {Float, LibDecimalFloat} from "rain.math.float/lib/LibDecimalFloat.sol";

contract LibOpMaxTest is OpTest {
    /// Directly test the integrity logic of LibOpMax. This tests the happy
    /// path where the inputs input and calc match.
    function testOpMaxIntegrityHappy(IntegrityCheckState memory state, uint8 inputs, uint16 operandData) external pure {
        inputs = uint8(bound(inputs, 2, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) = LibOpMax.integrity(state, LibOperand.build(inputs, 1, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpMax. This tests the unhappy
    /// path where the operand is invalid due to 0 inputs.
    function testOpMaxIntegrityUnhappyZeroInputs(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpMax.integrity(state, OperandV2.wrap(0));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpMax. This tests the unhappy
    /// path where the operand is invalid due to 1 inputs.
    function testOpMaxIntegrityUnhappyOneInput(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpMax.integrity(state, OperandV2.wrap(bytes32(uint256(0x010000))));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpMax.
    function testOpMaxRun(StackItem[] memory inputs) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.assume(inputs.length >= 2);
        vm.assume(inputs.length <= 0x0F);
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(state, operand, LibOpMax.referenceFn, LibOpMax.integrity, LibOpMax.run, inputs);
    }

    /// Test the eval of `max` opcode parsed from a string. Tests zero inputs.
    function testOpMaxEvalZeroInputs() external {
        checkBadInputs("_: max();", 0, 2, 0);
    }

    /// Test the eval of `max` opcode parsed from a string. Tests one input.
    function testOpMaxEvalOneInput() external {
        checkBadInputs("_: max(5e-18);", 1, 2, 1);
        checkBadInputs("_: max(0);", 1, 2, 1);
        checkBadInputs("_: max(1e-18);", 1, 2, 1);
        checkBadInputs("_: max(max-positive-value());", 1, 2, 1);
    }

    function testOpMaxZeroOutputs() external {
        checkBadOutputs(": max(0 0);", 2, 1, 0);
    }

    function testOpMaxEvalTwoOutputs() external {
        checkBadOutputs("_ _: max(0 0);", 2, 1, 2);
    }

    /// Test the eval of `max` opcode parsed from a string. Tests two inputs.
    function testOpMaxEval2InputsHappy() external view {
        checkHappy("_: max(0 0);", 0, "0 > 0 ? 0 : 1");
        checkHappy("_: max(1 0);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "1 > 0 ? 1 : 0");
        checkHappy(
            "_: max(max-positive-value() 0);",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "max-positive-value() > 0 ? max-positive-value() : 0"
        );
        checkHappy("_: max(0 1);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "0 > 1 ? 0 : 1");
        checkHappy("_: max(1 1);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "1 > 1 ? 1 : 1");
        checkHappy(
            "_: max(0 max-positive-value());",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "0 > max-positive-value() ? 0 : max-positive-value()"
        );
        checkHappy(
            "_: max(1 max-positive-value());",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "1 > max-positive-value() ? 1 : max-positive-value()"
        );
        checkHappy(
            "_: max(max-positive-value() 1);",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "1 > max-positive-value() ? 1 : max-positive-value()"
        );
        checkHappy(
            "_: max(max-positive-value() max-positive-value());",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "max-positive-value() > max-positive-value() ? max-positive-value() : max-positive-value()"
        );
        checkHappy("_: max(0 2);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "0 > 2 ? 0 : 2");
        checkHappy("_: max(1 2);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "1 > 2 ? 1 : 2");
        checkHappy("_: max(2 2);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "2 > 2 ? 2 : 2");
        checkHappy("_: max(-1 1);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "-1 > 1 ? -1 : 1");
        checkHappy("_: max(-1 0);", Float.unwrap(LibDecimalFloat.packLossless(0, 0)), "-1 > 0 ? -1 : 0");
        checkHappy("_: max(-1 -1);", Float.unwrap(LibDecimalFloat.packLossless(-1, 0)), "-1 > -1 ? -1 : -1");
        checkHappy("_: max(-1 -2);", Float.unwrap(LibDecimalFloat.packLossless(-1, 0)), "-1 > -2 ? -1 : -2");
        checkHappy("_: max(-2 -1);", Float.unwrap(LibDecimalFloat.packLossless(-1, 0)), "-2 > -1 ? -2 : -1");
        checkHappy("_: max(-1.1 -1.0);", Float.unwrap(LibDecimalFloat.packLossless(-1, 0)), "-1.1 > -1.2 ? -1.1 : -1.2");
        checkHappy("_: max(-1.0 -1);", Float.unwrap(LibDecimalFloat.packLossless(-1, 0)), "-1.0 > -1.0 ? -1.0 : -1.0");
    }

    /// Test the eval of `max` opcode parsed from a string. Tests three inputs.
    function testOpMaxEval3InputsHappy() external view {
        checkHappy("_: max(0 0 0);", 0, "0 0 0");
        checkHappy("_: max(1 0 0);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "1 0 0");
        checkHappy("_: max(2 0 0);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "2 0 0");
        checkHappy("_: max(0 1 0);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "0 1 0");
        checkHappy("_: max(1 1 0);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "1 1 0");
        checkHappy("_: max(2 1 0);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "2 1 0");
        checkHappy("_: max(0 2 0);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "0 2 0");
        checkHappy("_: max(1 2 0);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "1 2 0");
        checkHappy("_: max(2 2 0);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "2 2 0");
        checkHappy("_: max(0 0 1);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "0 0 1");
        checkHappy("_: max(1 0 1);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "1 0 1");
        checkHappy("_: max(2 0 1);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "2 0 1");
        checkHappy("_: max(0 1 1);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "0 1 1");
        checkHappy("_: max(1 1 1);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "1 1 1");
        checkHappy("_: max(2 1 1);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "2 1 1");
        checkHappy("_: max(0 2 1);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "0 2 1");
        checkHappy("_: max(1 2 1);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "1 2 1");
        checkHappy("_: max(2 2 1);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "2 2 1");
        checkHappy("_: max(0 0 2);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "0 0 2");
        checkHappy("_: max(1 0 2);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "1 0 2");
        checkHappy("_: max(2 0 2);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "2 0 2");
        checkHappy("_: max(0 1 2);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "0 1 2");
        checkHappy("_: max(1 1 2);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "1 1 2");
        checkHappy("_: max(2 1 2);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "2 1 2");
        checkHappy("_: max(0 2 2);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "0 2 2");
        checkHappy("_: max(1 2 2);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "1 2 2");
        checkHappy("_: max(2 2 2);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "2 2 2");
        checkHappy(
            "_: max(0 0 max-positive-value());",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "0 0 max-positive-value()"
        );
        checkHappy(
            "_: max(1 0 max-positive-value());",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "1 0 max-positive-value()"
        );
        checkHappy(
            "_: max(2 0 max-positive-value());",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "2 0 max-positive-value()"
        );
        checkHappy(
            "_: max(0 1 max-positive-value());",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "0 1 max-positive-value()"
        );
        checkHappy(
            "_: max(1 1 max-positive-value());",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "1 1 max-positive-value()"
        );
        checkHappy(
            "_: max(2 1 max-positive-value());",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "2 1 max-positive-value()"
        );
        checkHappy(
            "_: max(0 2 max-positive-value());",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "0 2 max-positive-value()"
        );
        checkHappy(
            "_: max(1 2 max-positive-value());",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "1 2 max-positive-value()"
        );
        checkHappy(
            "_: max(2 2 max-positive-value());",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "2 2 max-positive-value()"
        );
        checkHappy("_: max(-1.1 -1.0 0);", Float.unwrap(LibDecimalFloat.packLossless(0, 0)), "-1.1 -1.0 0");
        checkHappy("_: max(-1.0 -1 0);", Float.unwrap(LibDecimalFloat.packLossless(0, 0)), "-1.0 -1 0");
        checkHappy("_: max(-1.0 1.0 0);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "-1.0 -1.0 0");
    }

    /// Test the eval of `max` opcode parsed from a string.
    /// Tests that operands are disallowed.
    function testOpMaxEvalOperandDisallowed() external {
        checkDisallowedOperand("_: max<0>(0 0 0);");
        checkDisallowedOperand("_: max<1>(0 0 0);");
        checkDisallowedOperand("_: max<2>(0 0 0);");
        checkDisallowedOperand("_: max<3 1>(0 0 0);");
    }
}
