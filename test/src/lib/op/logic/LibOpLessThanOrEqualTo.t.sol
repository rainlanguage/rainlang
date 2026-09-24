// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpLessThanOrEqualTo} from "../../../../../src/lib/op/logic/LibOpLessThanOrEqualTo.sol";
import {IntegrityCheckState, BadOpInputsLength} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {
    OperandV2,
    SourceIndexV2,
    FullyQualifiedNamespace,
    EvalV4,
    StackItem
} from "rainlang-interface-0.2.9/src/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {SignedContextV1} from "rainlang-interface-0.2.9/src/interface/IInterpreterCallerV4.sol";
import {LibContext} from "rainlang-interface-0.2.9/src/lib/caller/LibContext.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {Float, LibDecimalFloat} from "rain-math-float-0.2.1/src/lib/LibDecimalFloat.sol";
import {OpcodeIOOverflow} from "../../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../../src/lib/parse/LibParseError.sol";

contract LibOpLessThanOrEqualToTest is OpTest {
    /// Directly test the integrity logic of LibOpLessThanOrEqualTo. The calc
    /// inputs must match the operand inputs, and the calc outputs must be 1.
    function testOpLessThanOrEqualToIntegrityHappy(
        IntegrityCheckState memory state,
        uint8 inputs,
        uint8 outputs,
        uint16 operandData
    ) external pure {
        inputs = uint8(bound(inputs, 2, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpLessThanOrEqualTo.integrity(state, LibOperand.build(inputs, outputs, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpLessThanOrEqualTo. This tests
    /// the unhappy path where the operand is invalid due to 0 inputs.
    function testOpLessThanOrEqualToIntegrityUnhappyZeroInputs(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpLessThanOrEqualTo.integrity(state, OperandV2.wrap(0));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the integrity logic of LibOpLessThanOrEqualTo. This tests
    /// the unhappy path where the operand is invalid due to 1 input.
    function testOpLessThanOrEqualToIntegrityUnhappyOneInput(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpLessThanOrEqualTo.integrity(state, OperandV2.wrap(bytes32(uint256(0x010000))));
        // Calc inputs will be minimum 2.
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpLessThanOrEqualTo.
    function testOpLessThanOrEqualToRun(StackItem input1, StackItem input2) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = input1;
        inputs[1] = input2;
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(
            state,
            operand,
            LibOpLessThanOrEqualTo.referenceFn,
            LibOpLessThanOrEqualTo.integrity,
            LibOpLessThanOrEqualTo.run,
            inputs
        );
    }

    /// Directly test the runtime logic of LibOpLessThanOrEqualTo for an
    /// arbitrary number of inputs.
    function testOpLessThanOrEqualToRunVariadic(StackItem[] memory inputs) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.assume(inputs.length >= 2);
        vm.assume(inputs.length <= 0x0F);
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(
            state,
            operand,
            LibOpLessThanOrEqualTo.referenceFn,
            LibOpLessThanOrEqualTo.integrity,
            LibOpLessThanOrEqualTo.run,
            inputs
        );
    }

    /// Directly test the runtime logic of LibOpLessThanOrEqualTo for an
    /// arbitrary number of ascending inputs. Random inputs almost never
    /// ascend, so this covers the branch where the whole chain holds.
    function testOpLessThanOrEqualToRunVariadicAscending(uint8 length) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        length = uint8(bound(length, 2, 0x0F));
        StackItem[] memory inputs = new StackItem[](length);
        for (uint256 i = 0; i < inputs.length; i++) {
            // Exponent is fixed so the coefficient alone orders the inputs.
            // forge-lint: disable-next-line(unsafe-typecast)
            inputs[i] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(int256(i), 0)));
        }
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(
            state,
            operand,
            LibOpLessThanOrEqualTo.referenceFn,
            LibOpLessThanOrEqualTo.integrity,
            LibOpLessThanOrEqualTo.run,
            inputs
        );
    }

    /// Test the eval of greater than or equal to opcode parsed from a string.
    /// Tests 2 inputs. Both inputs are 0.
    function testOpLessThanOrEqualToEval2ZeroInputs() external view {
        bytes memory bytecode = I_DEPLOYER.parse2("_: less-than-or-equal-to(0 0);");
        (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: FullyQualifiedNamespace.wrap(0),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: LibContext.build(new bytes32[][](0), new SignedContextV1[](0)),
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );

        assertEq(stack.length, 1);
        assertEq(StackItem.unwrap(stack[0]), bytes32(uint256(1)));
        assertEq(kvs.length, 0);
    }

    /// Test the eval of greater than or equal to opcode parsed from a string.
    /// Tests 2 inputs. The first input is 0, the second input is 1.
    function testOpLessThanOrEqualToEval2InputsFirstZeroSecondOne() external view {
        bytes memory bytecode = I_DEPLOYER.parse2("_: less-than-or-equal-to(0 1);");
        (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: FullyQualifiedNamespace.wrap(0),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: LibContext.build(new bytes32[][](0), new SignedContextV1[](0)),
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );

        assertEq(stack.length, 1);
        assertEq(StackItem.unwrap(stack[0]), bytes32(uint256(1)));
        assertEq(kvs.length, 0);
    }

    /// Test the eval of greater than or equal to opcode parsed from a string.
    /// Tests 2 inputs. The first input is 1, the second input is 0.
    function testOpLessThanOrEqualToEval2InputsFirstOneSecondZero() external view {
        bytes memory bytecode = I_DEPLOYER.parse2("_: less-than-or-equal-to(1 0);");
        (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: FullyQualifiedNamespace.wrap(0),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: LibContext.build(new bytes32[][](0), new SignedContextV1[](0)),
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );

        assertEq(stack.length, 1);
        assertEq(StackItem.unwrap(stack[0]), bytes32(0));
        assertEq(kvs.length, 0);
    }

    /// Test the eval of greater than or equal to opcode parsed from a string.
    /// Tests 2 inputs. Both inputs are 1.
    function testOpLessThanOrEqualToEval2InputsBothOne() external view {
        bytes memory bytecode = I_DEPLOYER.parse2("_: less-than-or-equal-to(1 1);");
        (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: FullyQualifiedNamespace.wrap(0),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: LibContext.build(new bytes32[][](0), new SignedContextV1[](0)),
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );

        assertEq(stack.length, 1);
        assertEq(StackItem.unwrap(stack[0]), bytes32(uint256(1)));
        assertEq(kvs.length, 0);
    }

    /// Test 1.1 <= 1.2, which should return 1.
    function testOpLessThanOrEqualToEvalOnePointOneLteOnePointTwo() external view {
        checkHappy("_: less-than-or-equal-to(1.1 1.2);", bytes32(uint256(1)), "");
    }

    /// Test 1.0 <= 1, which should return 1 (equal).
    function testOpLessThanOrEqualToEvalOnePointZeroLteOne() external view {
        checkHappy("_: less-than-or-equal-to(1.0 1);", bytes32(uint256(1)), "");
    }

    /// Test -1.1 <= -1.2, which should return 0.
    function testOpLessThanOrEqualToEvalNegOnePointOneLteNegOnePointTwo() external view {
        checkHappy("_: less-than-or-equal-to(-1.1 -1.2);", 0, "");
    }

    /// Test -1 <= 0, which should return 1.
    function testOpLessThanOrEqualToEvalNegOneLteZero() external view {
        checkHappy("_: less-than-or-equal-to(-1 0);", bytes32(uint256(1)), "");
    }

    /// Test the eval of less than or equal to opcode parsed from a string.
    /// Tests 3 inputs, which chain as `0 <= 1 <= 2`. This is the bounds check
    /// form, `less-than-or-equal-to(min x max)`.
    function testOpLessThanOrEqualToEval3InputsAscending() external view {
        checkHappy("_: less-than-or-equal-to(0 1 2);", bytes32(uint256(1)), "");
    }

    /// Test the eval of less than or equal to opcode parsed from a string.
    /// Tests 3 equal inputs, which satisfy the chain because the comparison is
    /// not strict.
    function testOpLessThanOrEqualToEval3InputsAllEqual() external view {
        checkHappy("_: less-than-or-equal-to(1 1 1);", bytes32(uint256(1)), "");
    }

    /// Test the eval of less than or equal to opcode parsed from a string. The
    /// bounds check form where the value sits below the minimum.
    function testOpLessThanOrEqualToEval3InputsBelowMin() external view {
        checkHappy("_: less-than-or-equal-to(1 0 2);", 0, "");
    }

    /// Test the eval of less than or equal to opcode parsed from a string. The
    /// bounds check form where the value sits above the maximum.
    function testOpLessThanOrEqualToEval3InputsAboveMax() external view {
        checkHappy("_: less-than-or-equal-to(0 3 2);", 0, "");
    }

    /// Test the eval of less than or equal to opcode parsed from a string.
    /// Tests 3 inputs where only the outer pair is ordered.
    ///
    /// The case that separates the two readings, so the expected value is
    /// derived rather than observed:
    ///
    /// - chained, as Clojure's `(<= 0 2 1)` does, expands to
    ///   `0 <= 2 && 2 <= 1` = **false**;
    /// - every input against the first expands to `0 <= 2 && 0 <= 1` = **true**.
    ///
    /// A `1` here would mean the second reading had been adopted silently.
    function testOpLessThanOrEqualToEval3InputsOnlyOuterOrdered() external view {
        checkHappy("_: less-than-or-equal-to(0 2 1);", 0, "");
    }

    /// The bounds check the variadic form exists for: `min <= x <= max` in one
    /// call rather than two `ensure` bodies. Every expectation below expands
    /// from the chained reading and is checkable by eye:
    /// `1 <= 2 && 2 <= 3` true; at the floor `1 <= 1 && 1 <= 3` true; at the
    /// ceiling `1 <= 3 && 3 <= 3` true; below it `1 <= 0` false; above it
    /// `3 <= 3` holds but `1 <= 4 && 4 <= 3` false.
    function testOpLessThanOrEqualToEvalBoundsCheck() external view {
        checkHappy("_: less-than-or-equal-to(1 2 3);", bytes32(uint256(1)), "");
        checkHappy("_: less-than-or-equal-to(1 1 3);", bytes32(uint256(1)), "");
        checkHappy("_: less-than-or-equal-to(1 3 3);", bytes32(uint256(1)), "");
        checkHappy("_: less-than-or-equal-to(1 0 3);", 0, "");
        checkHappy("_: less-than-or-equal-to(1 4 3);", 0, "");
    }

    /// Test the eval of less than or equal to opcode parsed from a string.
    /// Tests the maximum 15 ascending inputs.
    function testOpLessThanOrEqualToEval15InputsAscending() external view {
        checkHappy("_: less-than-or-equal-to(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14);", bytes32(uint256(1)), "");
    }

    /// Test the eval of less than or equal to opcode parsed from a string.
    /// Tests the maximum 15 inputs where only the final pair breaks the chain.
    function testOpLessThanOrEqualToEval15InputsLastPairDescends() external view {
        checkHappy("_: less-than-or-equal-to(0 1 2 3 4 5 6 7 8 9 10 11 12 13 12);", 0, "");
    }

    /// Test that a less than or equal to without inputs fails integrity check.
    function testOpLessThanOrEqualToEvalFail0Inputs() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 0, 2, 0));
        bytes memory bytecode = I_DEPLOYER.parse2("_: less-than-or-equal-to();");
        (bytecode);
    }

    /// Test that a less than or equal to with 1 input fails integrity check.
    function testOpLessThanOrEqualToEvalFail1Input() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 1, 2, 1));
        bytes memory bytecode = I_DEPLOYER.parse2("_: less-than-or-equal-to(0x00);");
        (bytecode);
    }

    function testOpLessThanOrEqualToZeroOutputs() external {
        checkBadOutputs(": less-than-or-equal-to(1 2);", 2, 1, 0);
    }

    function testOpLessThanOrEqualToTwoOutputs() external {
        checkBadOutputs("_ _: less-than-or-equal-to(1 2);", 2, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpLessThanOrEqualToEvalOperandDisallowed() external {
        checkUnhappyParse("_: less-than-or-equal-to<0>(1 2);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }

    /// 16 inputs overflows the 4 bit input nybble of the opcode io byte, so the
    /// parser rejects it. 15 inputs is the maximum.
    function testOpLessThanOrEqualToEvalFail16Inputs() external {
        bytes memory rainlang = bytes("_: less-than-or-equal-to(1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1);");
        vm.expectRevert(abi.encodeWithSelector(OpcodeIOOverflow.selector, LibParseError.tagErrorOffset(57)));
        I_PARSER.unsafeParse(rainlang);
    }
}
