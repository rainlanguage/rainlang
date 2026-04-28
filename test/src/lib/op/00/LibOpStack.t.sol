// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Pointer} from "rain.solmem/lib/LibPointer.sol";

import {OperandV2, SourceIndexV2, EvalV4, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibContext} from "rain.interpreter.interface/lib/caller/LibContext.sol";
import {LibOpStack} from "../../../../../src/lib/op/00/LibOpStack.sol";
import {OutOfBoundsStackRead} from "../../../../../src/error/ErrIntegrity.sol";
import {LibIntegrityCheck, IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {LibInterpreterState, InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibInterpreterStateFingerprint} from "test/lib/state/LibInterpreterStateFingerprint.sol";
import {FullyQualifiedNamespace} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";
import {OpTest, PRE, POST} from "test/abstract/OpTest.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV4.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {BadOpOutputsLength} from "rain.interpreter.interface/error/ErrIntegrity.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";

/// @title LibOpStackTest
/// @notice Test the runtime and integrity time logic of LibOpStack.
contract LibOpStackTest is OpTest {
    using LibInterpreterState for InterpreterState;
    using LibInterpreterStateFingerprint for InterpreterState;

    function integrityExternal(IntegrityCheckState memory state, OperandV2 operand)
        external
        pure
        returns (uint256, uint256)
    {
        return LibOpStack.integrity(state, operand);
    }

    /// Directly test the integrity logic of LibOpStack. The operand always
    /// puts a single value on the stack. This tests the happy path where the
    /// operand points to a value in the stack.
    function testOpStackIntegrity(
        bytes memory bytecode,
        uint256 stackIndex,
        bytes32[] memory constants,
        OperandV2 operand
    ) external pure {
        stackIndex = bound(stackIndex, 1, type(uint256).max);
        operand = OperandV2.wrap(bytes32(bound(uint256(OperandV2.unwrap(operand)), 0, stackIndex - 1)));
        IntegrityCheckState memory state = LibIntegrityCheck.newState(bytecode, stackIndex, constants);

        (uint256 inputs, uint256 outputs) = LibOpStack.integrity(state, operand);

        assertEq(inputs, 0);
        assertEq(outputs, 1);
    }

    /// Directly test the integrity logic of LibOpStack. This tests the case
    /// where the operand points past the end of the stack, which MUST always
    /// error as an OOB read.
    function testOpStackIntegrityOOBStack(
        bytes memory bytecode,
        uint16 stackIndex,
        bytes32[] memory constants,
        uint16 readIndex,
        uint256 opIndex
    ) external {
        stackIndex = uint16(bound(stackIndex, 0, uint256(type(uint16).max)));
        readIndex = uint16(bound(readIndex, stackIndex, uint256(type(uint16).max)));
        OperandV2 operand = LibOperand.build(0, 1, readIndex);
        IntegrityCheckState memory state = LibIntegrityCheck.newState(bytecode, stackIndex, constants);
        state.opIndex = opIndex;

        vm.expectRevert(abi.encodeWithSelector(OutOfBoundsStackRead.selector, state.opIndex, stackIndex, readIndex));
        this.integrityExternal(state, operand);
    }

    /// Directly test the runtime logic of LibOpStack. This tests that the
    /// operand always puts a single value on the stack.
    /// forge-config: default.fuzz.runs = 100
    function testOpStackRun(StackItem[][] memory stacks, uint256 stackIndex) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        StackItem stackValue;
        {
            vm.assume(stacks.length > 0);
            state.stackBottoms = LibInterpreterState.stackBottoms(stacks);
            state.sourceIndex = bound(state.sourceIndex, 0, stacks.length - 1);
            StackItem[] memory stack = stacks[state.sourceIndex];
            vm.assume(stack.length > 0);
            stackIndex = bound(stackIndex, 0, stack.length - 1);
            stackValue = stack[stack.length - (stackIndex + 1)];
        }

        Pointer stackBottom;
        Pointer stackTop;
        Pointer expectedStackTopAfter;
        Pointer end;
        {
            bytes32 pre = PRE;
            bytes32 post = POST;
            assembly ("memory-safe") {
                end := mload(0x40)
                mstore(end, post)
                expectedStackTopAfter := add(end, 0x20)
                mstore(expectedStackTopAfter, 0)
                stackTop := add(expectedStackTopAfter, 0x20)
                mstore(stackTop, pre)
                stackBottom := add(stackTop, 0x20)
                mstore(0x40, stackBottom)
            }
        }

        // Stack doesn't modify the state.
        bytes32 stateFingerprintBefore = state.fingerprint();

        // Run the opcode.
        Pointer stackTopAfter = LibOpStack.run(state, OperandV2.wrap(bytes32(stackIndex)), stackTop);

        assertEq(Pointer.unwrap(stackTopAfter), Pointer.unwrap(expectedStackTopAfter));

        // Check that the opcode didn't modify the state.
        assertEq(state.fingerprint(), stateFingerprintBefore, "state");

        // The stack value should be on the stack without modifying any other data.
        bytes32 actualPost;
        bytes32 actualStackValue;
        bytes32 actualPre;
        assembly ("memory-safe") {
            actualPost := mload(end)
            actualStackValue := mload(add(end, 0x20))
            actualPre := mload(add(end, 0x40))
        }

        assertEq(actualPost, POST, "post");
        assertEq(actualStackValue, StackItem.unwrap(stackValue), "stackValue");
        assertEq(actualPre, PRE, "pre");
    }

    /// Test that run() and referenceFn() produce the same value.
    /// forge-config: default.fuzz.runs = 100
    function testOpStackRunReferenceFnParity(StackItem[][] memory stacks, uint256 stackIndex) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        vm.assume(stacks.length > 0);
        state.stackBottoms = LibInterpreterState.stackBottoms(stacks);
        state.sourceIndex = bound(state.sourceIndex, 0, stacks.length - 1);
        StackItem[] memory stack = stacks[state.sourceIndex];
        vm.assume(stack.length > 0);
        stackIndex = bound(stackIndex, 0, stack.length - 1);

        OperandV2 operand = OperandV2.wrap(bytes32(stackIndex));
        StackItem[] memory inputs = new StackItem[](0);

        StackItem[] memory referenceOutputs = LibOpStack.referenceFn(state, operand, inputs);
        assertEq(referenceOutputs.length, 1, "referenceFn outputs length");

        // The expected value from the stack array directly.
        StackItem expectedValue = stack[stack.length - (stackIndex + 1)];
        assertEq(StackItem.unwrap(referenceOutputs[0]), StackItem.unwrap(expectedValue), "referenceFn value");
    }

    /// Test the eval of a stack opcode parsed from a string.
    function testOpStackEval() external view {
        bytes memory bytecode = I_DEPLOYER.parse2("foo: 1, bar: foo, _: -1;");
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
        assertEq(stack.length, 3);
        assertEq(StackItem.unwrap(stack[0]), Float.unwrap(LibDecimalFloat.packLossless(-1, 0)));
        assertEq(StackItem.unwrap(stack[1]), StackItem.unwrap(stack[2]));
        assertEq(StackItem.unwrap(stack[2]), Float.unwrap(LibDecimalFloat.packLossless(1, 0)));
        assertEq(kvs.length, 0);
    }

    /// Test the eval of several stack opcodes parsed from a string.
    function testOpStackEvalSeveral() external view {
        bytes memory bytecode = I_DEPLOYER.parse2("foo: 1, bar: foo, _ baz: bar bar, bing _:foo baz;");

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
        assertEq(stack.length, 6);
        assertEq(StackItem.unwrap(stack[0]), Float.unwrap(LibDecimalFloat.packLossless(1, 0)));
        assertEq(StackItem.unwrap(stack[1]), Float.unwrap(LibDecimalFloat.packLossless(1, 0)));
        assertEq(StackItem.unwrap(stack[2]), Float.unwrap(LibDecimalFloat.packLossless(1, 0)));
        assertEq(StackItem.unwrap(stack[3]), Float.unwrap(LibDecimalFloat.packLossless(1, 0)));
        assertEq(StackItem.unwrap(stack[4]), Float.unwrap(LibDecimalFloat.packLossless(1, 0)));
        assertEq(StackItem.unwrap(stack[5]), Float.unwrap(LibDecimalFloat.packLossless(1, 0)));
        assertEq(kvs.length, 0);
    }

    /// It is an error to have multiple outputs for a stack item.
    function testOpStackMultipleOutputErrorSugared() external {
        checkUnhappyParse2("foo: 1, _ _: foo;", abi.encodeWithSelector(BadOpOutputsLength.selector, 1, 1, 2));
    }

    /// It is an error to have multiple outputs for a stack item.
    function testOpStackMultipleOutputErrorUnsugared() external {
        checkUnhappyParse2("foo: 1, _ _: stack<0>();", abi.encodeWithSelector(BadOpOutputsLength.selector, 1, 1, 2));
    }

    /// It is an error to have zero outputs for a stack item.
    function testOpStackZeroOutputErrorSugared() external {
        checkUnhappyParse2("foo: 1,: foo;", abi.encodeWithSelector(BadOpOutputsLength.selector, 1, 1, 0));
    }

    /// It is an error to have zero outputs for a stack item.
    function testOpStackZeroOutputErrorUnsugared() external {
        checkUnhappyParse2("foo: 1,: stack<0>();", abi.encodeWithSelector(BadOpOutputsLength.selector, 1, 1, 0));
    }
}
