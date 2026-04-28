// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOpE} from "../../../../../src/lib/op/math/LibOpE.sol";
import {LibOperand, OperandV2} from "test/lib/operand/LibOperand.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {
    EvalV4,
    StackItem,
    FullyQualifiedNamespace,
    SourceIndexV2
} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV4.sol";
import {LibContext} from "rain.interpreter.interface/lib/caller/LibContext.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";

/// @title LibOpETest
/// @notice Tests for the mathematical constant e opcode.
contract LibOpETest is OpTest {
    /// Directly test the integrity logic of LibOpE.
    function testOpEIntegrity(IntegrityCheckState memory state, uint8 inputs, uint8 outputs, uint16 operandData)
        external
        pure
    {
        inputs = uint8(bound(inputs, 0, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpE.integrity(state, LibOperand.build(inputs, outputs, operandData));

        assertEq(calcInputs, 0);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpE. This tests that the
    /// opcode correctly pushes the mathematical constant e onto the stack.
    function testOpERun(uint16 operandData) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        OperandV2 operand = LibOperand.build(0, 1, operandData);
        StackItem[] memory inputs = new StackItem[](0);
        opReferenceCheck(state, operand, LibOpE.referenceFn, LibOpE.integrity, LibOpE.run, inputs);
    }

    /// Test the eval of a mathematical constant e opcode parsed from a string.
    function testOpEEval() external view {
        bytes memory bytecode = I_DEPLOYER.parse2("_: e();");

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
        assertEq(StackItem.unwrap(stack[0]), Float.unwrap(LibDecimalFloat.FLOAT_E));
        assertEq(kvs.length, 0);
    }

    function testOpEEvalOneInput() external {
        checkBadInputs("_: e(0x00);", 1, 0, 1);
    }

    function testOpEEvalZeroOutputs() external {
        checkBadOutputs(": e();", 0, 1, 0);
    }

    function testOpEEvalTwoOutputs() external {
        checkBadOutputs("_ _: e();", 0, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpEEvalOperandDisallowed() external {
        checkUnhappyParse("_: e<0>();", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
