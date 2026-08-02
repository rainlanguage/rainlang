// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOpPi, FLOAT_PI} from "../../../../../src/lib/op/math/LibOpPi.sol";
import {LibOperand, OperandV2} from "test/lib/operand/LibOperand.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {
    EvalV4,
    StackItem,
    FullyQualifiedNamespace,
    SourceIndexV2
} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterV4.sol";
import {SignedContextV1} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterCallerV4.sol";
import {LibContext} from "rain-interpreter-interface-0.1.0/src/lib/caller/LibContext.sol";
import {Float} from "rain-math-float-0.1.1/src/lib/LibDecimalFloat.sol";

/// @title LibOpPiTest
/// @notice Tests for the mathematical constant pi opcode.
contract LibOpPiTest is OpTest {
    /// Directly test the integrity logic of LibOpPi.
    function testOpPiIntegrity(IntegrityCheckState memory state, uint8 inputs, uint8 outputs, uint16 operandData)
        external
        pure
    {
        inputs = uint8(bound(inputs, 0, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpPi.integrity(state, LibOperand.build(inputs, outputs, operandData));

        assertEq(calcInputs, 0);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpPi. This tests that the
    /// opcode correctly pushes the mathematical constant pi onto the stack.
    function testOpPiRun(uint16 operandData) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        OperandV2 operand = LibOperand.build(0, 1, operandData);
        StackItem[] memory inputs = new StackItem[](0);
        opReferenceCheck(state, operand, LibOpPi.referenceFn, LibOpPi.integrity, LibOpPi.run, inputs);
    }

    /// Test the eval of a mathematical constant pi opcode parsed from a string.
    function testOpPiEval() external view {
        bytes memory bytecode = I_DEPLOYER.parse2("_: pi();");

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
        assertEq(StackItem.unwrap(stack[0]), Float.unwrap(FLOAT_PI));
        assertEq(kvs.length, 0);
    }

    function testOpPiEvalOneInput() external {
        checkBadInputs("_: pi(0x00);", 1, 0, 1);
    }

    function testOpPiEvalZeroOutputs() external {
        checkBadOutputs(": pi();", 0, 1, 0);
    }

    function testOpPiEvalTwoOutputs() external {
        checkBadOutputs("_ _: pi();", 0, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpPiEvalOperandDisallowed() external {
        checkUnhappyParse("_: pi<0>();", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
