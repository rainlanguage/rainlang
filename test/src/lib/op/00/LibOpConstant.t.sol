// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";

import {LibContext} from "rain.interpreter.interface/lib/caller/LibContext.sol";
import {LibOpConstant} from "../../../../../src/lib/op/00/LibOpConstant.sol";
import {OutOfBoundsConstantRead} from "../../../../../src/error/ErrIntegrity.sol";
import {LibInterpreterState, InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {
    OperandV2,
    SourceIndexV2,
    FullyQualifiedNamespace,
    EvalV4,
    StackItem
} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV4.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {BadOpOutputsLength} from "rain.interpreter.interface/error/ErrIntegrity.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";

/// @title LibOpConstantTest
/// @notice Test the runtime and integrity time logic of LibOpConstant.
contract LibOpConstantTest is OpTest {
    using LibInterpreterState for InterpreterState;

    function integrityExternal(IntegrityCheckState memory state, OperandV2 operand)
        external
        pure
        returns (uint256, uint256)
    {
        return LibOpConstant.integrity(state, operand);
    }

    /// Directly test the integrity logic of LibOpConstant. The operand always
    /// puts a single value on the stack. This tests the happy path where the
    /// operand points to a value in the constants array.
    function testOpConstantIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        vm.assume(state.constants.length > 0);
        operand = OperandV2.wrap(bytes32(bound(uint256(OperandV2.unwrap(operand)), 0, state.constants.length - 1)));

        (uint256 calcInputs, uint256 calcOutputs) = LibOpConstant.integrity(state, operand);

        assertEq(calcInputs, 0, "inputs");
        assertEq(calcOutputs, 1, "outputs");
    }

    /// Directly test the integrity logic of LibOpConstant. This tests the case
    /// where the operand points past the end of the constants array, which MUST
    /// always error as an OOB read.
    function testOpConstantIntegrityOOBConstants(IntegrityCheckState memory state, OperandV2 operand) external {
        operand = OperandV2.wrap(
            bytes32(bound(uint256(OperandV2.unwrap(operand)), state.constants.length, type(uint16).max))
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                OutOfBoundsConstantRead.selector, state.opIndex, state.constants.length, OperandV2.unwrap(operand)
            )
        );
        this.integrityExternal(state, operand);
    }

    /// Directly test the runtime logic of LibOpConstant. This tests that the
    /// operand always puts a single value on the stack.
    function testOpConstantRun(bytes32[] memory constants, uint16 constantIndex) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        state.constants = constants;
        vm.assume(state.constants.length > 0);
        vm.assume(state.constants.length <= type(uint16).max);
        constantIndex = uint16(bound(constantIndex, 0, uint16(state.constants.length - 1)));

        StackItem[] memory inputs = new StackItem[](0);
        opReferenceCheck(
            state,
            LibOperand.build(0, 1, constantIndex),
            LibOpConstant.referenceFn,
            LibOpConstant.integrity,
            LibOpConstant.run,
            inputs
        );
    }

    /// Test the case of an empty constants array via. an end to end test. We
    /// expect the deployer to revert, as the integrity check MUST fail.
    function testOpConstantEvalZeroConstants() external {
        vm.expectRevert(abi.encodeWithSelector(OutOfBoundsConstantRead.selector, 0, 0, 0));
        bytes memory bytecode = I_DEPLOYER.parse2("_ _ _: constant() constant() constant();");
        (bytecode);
    }

    /// Test the eval of a constant opcode parsed from a string.
    function testOpConstantEval() external view {
        bytes memory bytecode = I_DEPLOYER.parse2("_ _: 2 1.001;");

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
        assertEq(stack.length, 2);
        assertEq(StackItem.unwrap(stack[0]), Float.unwrap(LibDecimalFloat.packLossless(1.001e3, -3)));
        assertEq(StackItem.unwrap(stack[1]), Float.unwrap(LibDecimalFloat.packLossless(2, 0)));
        assertEq(kvs.length, 0);
    }

    /// Test integrity at the maximum operand index boundary (65535).
    /// Index 65535 is OOB for length 65535, valid for length 65536.
    function testOpConstantIntegrityMaxIndex() external {
        IntegrityCheckState memory state;
        state.constants = new bytes32[](0);
        OperandV2 operand = OperandV2.wrap(bytes32(uint256(0xFFFF)));

        // Set constants.length to 65535 via assembly. Index 65535 is OOB.
        bytes32[] memory constants = state.constants;
        assembly ("memory-safe") {
            mstore(constants, 0xFFFF)
        }
        vm.expectRevert(abi.encodeWithSelector(OutOfBoundsConstantRead.selector, state.opIndex, 0xFFFF, 0xFFFF));
        this.integrityExternal(state, operand);

        // Set constants.length to 65536. Index 65535 is now valid.
        assembly ("memory-safe") {
            mstore(constants, 0x10000)
        }
        (uint256 calcInputs, uint256 calcOutputs) = this.integrityExternal(state, operand);
        assertEq(calcInputs, 0, "inputs");
        assertEq(calcOutputs, 1, "outputs");
    }

    /// It is an error to have multiple outputs for a constant.
    function testOpConstantMultipleOutputErrorSugared() external {
        checkUnhappyParse2("_ _: 1;", abi.encodeWithSelector(BadOpOutputsLength.selector, 0, 1, 2));
    }

    /// It is an error to have multiple outputs for a constant.
    function testOpConstantMultipleOutputErrorUnsugared() external {
        checkUnhappyParse2("_:1,_ _: constant<0>();", abi.encodeWithSelector(BadOpOutputsLength.selector, 1, 1, 2));
    }

    /// It is an error to have zero outputs for a constant.
    function testOpConstantZeroOutputErrorSugared() external {
        checkUnhappyParse2(":1;", abi.encodeWithSelector(BadOpOutputsLength.selector, 0, 1, 0));
    }

    /// It is an error to have zero outputs for a constant.
    function testOpConstantZeroOutputErrorUnsugared() external {
        checkUnhappyParse2("_:1,:constant<0>();", abi.encodeWithSelector(BadOpOutputsLength.selector, 1, 1, 0));
    }
}
