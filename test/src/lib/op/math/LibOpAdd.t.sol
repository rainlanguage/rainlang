// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, IntegrityCheckState, OperandV2} from "test/abstract/OpTest.sol";
import {LibOpAdd} from "../../../../../src/lib/op/math/LibOpAdd.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {Float, LibDecimalFloat} from "rain.math.float/lib/LibDecimalFloat.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

contract LibOpAddTest is OpTest {
    /// Directly test the integrity logic of LibOpAdd. This tests the happy
    /// path where the inputs and calc match.
    function testOpAddIntegrityHappy(IntegrityCheckState memory state, uint8 inputs, uint16 operandData) external pure {
        inputs = uint8(bound(inputs, 2, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) = LibOpAdd.integrity(state, LibOperand.build(inputs, 1, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpAdd. This tests the unhappy
    /// path where the operand is invalid due to 0 inputs.
    function testOpAddIntegrityUnhappyZeroInputs(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpAdd.integrity(state, OperandV2.wrap(0));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpAdd. This tests the unhappy
    /// path where the operand is invalid due to 1 inputs.
    function testOpAddIntegrityUnhappyOneInput(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpAdd.integrity(state, OperandV2.wrap(bytes32(uint256(0x010000))));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpAdd.
    function testOpAddRun(StackItem[] memory inputs) external view {
        vm.assume(inputs.length >= 2);
        vm.assume(inputs.length <= 0x0F);
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);

        for (uint256 i = 0; i < inputs.length; i++) {
            (int256 signedCoefficient, int256 exponent) =
                LibDecimalFloat.unpack(Float.wrap(StackItem.unwrap(inputs[i])));
            exponent = int256(bound(exponent, type(int32).min, type(int32).max / 2));
            // Exponent bounds mean typecast is safe.
            //forge-lint: disable-next-line(unsafe-typecast)
            inputs[i] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(signedCoefficient, int32(exponent))));
        }

        opReferenceCheck(
            opTestDefaultInterpreterState(), operand, LibOpAdd.referenceFn, LibOpAdd.integrity, LibOpAdd.run, inputs
        );
    }

    /// Test the eval of `add` opcode parsed from a string. Tests zero inputs.
    function testOpAddEvalZeroInputs() external {
        checkBadInputs("_: add();", 0, 2, 0);
    }

    /// Test the eval of `add` opcode parsed from a string. Tests one input.
    function testOpAddEvalOneInput() external {
        checkBadInputs("_: add(5e-18);", 1, 2, 1);
    }

    function testOpAddEvalZeroOutputs() external {
        checkBadOutputs(": add(5e-18 6e-18);", 2, 1, 0);
    }

    function testOpAddEvalTwoOutput() external {
        checkBadOutputs("_ _: add(5e-18 6e-18);", 2, 1, 2);
    }

    /// Test the eval of `add` opcode parsed from a string. Tests two inputs.
    function testOpAddEval2InputsHappyExamples() external view {
        checkHappy("_: add(5 6);", Float.unwrap(LibDecimalFloat.packLossless(11e66, -66)), "5 + 6");
        checkHappy("_: add(6 5);", Float.unwrap(LibDecimalFloat.packLossless(11e66, -66)), "6 + 5");

        checkHappy("_: add(-5 -6);", Float.unwrap(LibDecimalFloat.packLossless(-11e66, -66)), "-5 + -6");
        checkHappy("_: add(-6 -5);", Float.unwrap(LibDecimalFloat.packLossless(-11e66, -66)), "-6 + -5");

        checkHappy("_: add(-5 6);", Float.unwrap(LibDecimalFloat.packLossless(1e67, -67)), "-5 + 6");
        checkHappy("_: add(6 -5);", Float.unwrap(LibDecimalFloat.packLossless(1e67, -67)), "6 + -5");

        // Mixed-sign cancellation to zero should canonicalize to the zero encoding.
        checkHappy("_: add(5 -5);", Float.unwrap(LibDecimalFloat.packLossless(0, -76)), "5 + -5");
        checkHappy("_: add(-5 5);", Float.unwrap(LibDecimalFloat.packLossless(0, -76)), "-5 + 5");
    }

    /// Test the eval of `add` opcode parsed from a string. Tests two inputs.
    /// Tests that adding 0 to 0 is 0.
    function testOpAddEval2InputsHappyZero() external view {
        checkHappy("_: add(0 0);", 0, "0 + 0");
    }

    /// Test the eval of `add` opcode parsed from a string. Tests two inputs.
    /// Tests that adding 0 to 1 is 1.
    function testOpAddEval2InputsHappyZeroOne() external view {
        checkHappy("_: add(0 1);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "0 + 1");
        checkHappy("_: add(1 0);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "0 + 1");
        checkHappy("_: add(0 1e-18);", Float.unwrap(LibDecimalFloat.packLossless(1, -18)), "0 + 1");
        checkHappy("_: add(1e-18 0);", Float.unwrap(LibDecimalFloat.packLossless(1, -18)), "1 + 0");
    }

    /// Test the eval of `add` opcode parsed from a string. Tests two inputs.
    /// Tests that adding 0 to max-positive-value() is max-positive-value().
    function testOpAddEval2InputsHappyZeroMax() external view {
        checkHappy(
            "_: add(0 max-positive-value());",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "0 + max-positive-value()"
        );
        checkHappy(
            "_: add(max-positive-value() 0);",
            Float.unwrap(LibDecimalFloat.packLossless(type(int224).max, type(int32).max)),
            "max-positive-value() + 0"
        );
    }

    /// Test the eval of `add` opcode parsed from a string. Tests three inputs.
    /// Tests the happy path where the addition does not overflow.
    function testOpAddEval3InputsHappy() external view {
        checkHappy("_: add(5 6 7);", Float.unwrap(LibDecimalFloat.packLossless(18e65, -65)), "5 + 6 + 7");
        checkHappy("_: add(6 5 7);", Float.unwrap(LibDecimalFloat.packLossless(18e65, -65)), "6 + 5 + 7");
        checkHappy("_: add(7 6 5);", Float.unwrap(LibDecimalFloat.packLossless(18e65, -65)), "7 + 6 + 5");
        checkHappy("_: add(5 7 6);", Float.unwrap(LibDecimalFloat.packLossless(18e65, -65)), "5 + 7 + 6");
        checkHappy("_: add(7 5 6);", Float.unwrap(LibDecimalFloat.packLossless(18e65, -65)), "7 + 5 + 6");
        checkHappy("_: add(5 -6 1);", Float.unwrap(LibDecimalFloat.packLossless(0, -76)), "5 + -6 + 1");
    }

    /// Test the eval of `add` opcode parsed from a string. Tests three inputs.
    /// Tests the unhappy path where the addition does overflow.
    function testOpAddEval3InputsUnhappy() external {
        checkUnhappyOverflow(
            "_: add(max-positive-value() max-positive-value() 1e-18);",
            26959946667150639794667015087019630673637144422540572481103610249214000000000,
            2147483638
        );
        checkUnhappyOverflow(
            "_: add(max-positive-value() 1e-18 max-positive-value());",
            26959946667150639794667015087019630673637144422540572481103610249214000000000,
            2147483638
        );
        checkUnhappyOverflow(
            "_: add(1e-18 max-positive-value() max-positive-value());",
            26959946667150639794667015087019630673637144422540572481103610249214000000000,
            2147483638
        );
        checkUnhappyOverflow(
            "_: add(max-positive-value() max-positive-value() max-positive-value());",
            40439920000725959692000522630529446010455716633810858721655415373821000000000,
            2147483638
        );
        checkUnhappyOverflow(
            "_: add(max-positive-value() max-positive-value() 0);",
            26959946667150639794667015087019630673637144422540572481103610249214000000000,
            2147483638
        );
        checkUnhappyOverflow(
            "_: add(max-positive-value() 0 max-positive-value());",
            26959946667150639794667015087019630673637144422540572481103610249214000000000,
            2147483638
        );
        checkUnhappyOverflow(
            "_: add(0 max-positive-value() max-positive-value());",
            26959946667150639794667015087019630673637144422540572481103610249214000000000,
            2147483638
        );
    }

    /// Test the eval of `add` opcode parsed from a string.
    /// Tests that operands are disallowed.
    function testOpAddEvalOperandDisallowed() external {
        checkDisallowedOperand("_: add<0>(0 0 0);");
        checkDisallowedOperand("_: add<1>(0 0 0);");
        checkDisallowedOperand("_: add<2>(0 0 0);");
        checkDisallowedOperand("_: add<0 0>(0 0 0);");
        checkDisallowedOperand("_: add<0 1>(0 0 0);");
        checkDisallowedOperand("_: add<1 0>(0 0 0);");
    }
}
