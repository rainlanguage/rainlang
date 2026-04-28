// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {stdError} from "forge-std/Test.sol";

import {LibOpContext} from "../../../../../src/lib/op/00/LibOpContext.sol";
import {OpTest} from "test/abstract/OpTest.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {
    OperandV2,
    SourceIndexV2,
    FullyQualifiedNamespace,
    EvalV4,
    StackItem
} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";

/// @title LibOpContextTest
/// @notice Test the LibOpContext library that includes the "context" word.
contract LibOpContextTest is OpTest {
    /// Directly test the integrity logic of LibOpContext. All operands are
    /// valid, so the integrity check should always pass. The inputs and
    /// outputs are always 0 and 1 respectively.
    function testOpContextIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpContext.integrity(state, operand);

        assertEq(calcInputs, 0, "inputs");
        assertEq(calcOutputs, 1, "outputs");
    }

    /// Directly test the runtime logic of LibOpContext. This tests that the
    /// values in the context matrix can be pushed to the stack via. the operand.
    /// forge-config: default.fuzz.runs = 100
    function testOpContextRun(bytes32[][] memory context, uint256 i, uint256 j) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        state.context = context;
        vm.assume(state.context.length > 0);
        vm.assume(state.context.length < type(uint8).max);
        i = bound(i, 0, state.context.length - 1);
        vm.assume(state.context[i].length > 0);
        vm.assume(state.context[i].length < type(uint8).max);
        j = bound(j, 0, state.context[i].length - 1);
        // Bounds ensure safe cast.
        //forge-lint: disable-next-line(unsafe-typecast)
        OperandV2 operand = LibOperand.build(0, 1, uint16(uint256(i) | uint256(j) << 8));
        StackItem[] memory inputs = new StackItem[](0);
        opReferenceCheck(state, operand, LibOpContext.referenceFn, LibOpContext.integrity, LibOpContext.run, inputs);
    }

    /// Directly test the reference logic of LibOpContext. This tests that the
    /// runtime logic will revert if the indexes are OOB. Tests that i is OOB.
    /// forge-config: default.fuzz.runs = 100
    function testOpContextRunOOBi(bytes32[][] memory context, uint256 i, uint256 j) external {
        vm.assume(context.length < type(uint8).max);
        i = bound(i, context.length, type(uint8).max);
        j = bound(j, 0, type(uint8).max);
        //Bounds ensure safe cast.
        //forge-lint: disable-next-line(incorrect-shift,unsafe-typecast)
        OperandV2 operand = LibOperand.build(0, 1, uint16(uint256(i) | uint256(j) << 8));
        vm.expectRevert(stdError.indexOOBError);
        this.internalTestOpContextRunOOBi(context, operand);
    }

    //forge-lint: disable-next-line(mixed-case-function)
    function internalTestOpContextRunOOBi(bytes32[][] memory context, OperandV2 operand) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        state.context = context;
        opReferenceCheck(
            state, operand, LibOpContext.referenceFn, LibOpContext.integrity, LibOpContext.run, new StackItem[](0)
        );
    }

    /// Directly test the reference logic of LibOpContext. This tests that the
    /// runtime logic will revert if the indexes are OOB. Tests that j is OOB.
    /// forge-config: default.fuzz.runs = 100
    //forge-lint: disable-next-line(mixed-case-function)
    function testOpContextRunOOBj(bytes32[][] memory context, uint256 i, uint256 j) external {
        vm.assume(context.length > 0);
        vm.assume(context.length < type(uint8).max);
        i = bound(i, 0, context.length - 1);
        vm.assume(context[i].length < type(uint8).max);
        j = bound(j, context[i].length, type(uint8).max);
        vm.expectRevert(stdError.indexOOBError);
        //forge-lint: disable-next-line(unsafe-typecast)
        OperandV2 operand = LibOperand.build(0, 1, uint16(uint256(i) | uint256(j) << 8));
        this.internalTestOpContextRunOOBj(context, operand);
    }

    //forge-lint: disable-next-line(mixed-case-function)
    function internalTestOpContextRunOOBj(bytes32[][] memory context, OperandV2 operand) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        state.context = context;
        opReferenceCheck(
            state, operand, LibOpContext.referenceFn, LibOpContext.integrity, LibOpContext.run, new StackItem[](0)
        );
    }

    /// Test the eval of context opcode parsed from a string. This tests 0 0.
    /// forge-config: default.fuzz.runs = 100
    function testOpContextEval00(bytes32[][] memory context) external view {
        vm.assume(context.length > 0);
        vm.assume(context[0].length > 0);
        bytes memory bytecode = I_DEPLOYER.parse2("_: context<0 0>();");

        (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: FullyQualifiedNamespace.wrap(0),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: context,
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );

        assertEq(stack.length, 1, "stack length");
        assertEq(StackItem.unwrap(stack[0]), context[0][0], "stack[0]");
        assertEq(kvs.length, 0, "kvs length");
    }

    /// Test the eval of context opcode parsed from a string. This tests 0 1.
    /// forge-config: default.fuzz.runs = 100
    function testOpContextEval01(bytes32[][] memory context) external view {
        vm.assume(context.length > 0);
        vm.assume(context[0].length > 1);
        bytes memory bytecode = I_DEPLOYER.parse2("_: context<0 1>();");
        (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: FullyQualifiedNamespace.wrap(0),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: context,
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );

        assertEq(stack.length, 1, "stack length");
        assertEq(StackItem.unwrap(stack[0]), context[0][1], "stack[0]");
        assertEq(kvs.length, 0, "kvs length");
    }

    /// Test the eval of context opcode parsed from a string. This tests 1 0.
    /// forge-config: default.fuzz.runs = 100
    function testOpContextEval10(bytes32[][] memory context) external view {
        vm.assume(context.length > 1);
        vm.assume(context[1].length > 0);
        bytes memory bytecode = I_DEPLOYER.parse2("_: context<1 0>();");

        (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: FullyQualifiedNamespace.wrap(0),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: context,
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );

        assertEq(stack.length, 1, "stack length");
        assertEq(StackItem.unwrap(stack[0]), context[1][0], "stack[0]");
        assertEq(kvs.length, 0, "kvs length");
    }

    /// Test the eval of context opcode parsed from a string. This tests 1 1.
    /// forge-config: default.fuzz.runs = 100
    function testOpContextEval11(bytes32[][] memory context) external view {
        vm.assume(context.length > 1);
        vm.assume(context[1].length > 1);
        bytes memory bytecode = I_DEPLOYER.parse2("_: context<1 1>();");

        (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: FullyQualifiedNamespace.wrap(0),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: context,
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );

        assertEq(stack.length, 1, "stack length");
        assertEq(StackItem.unwrap(stack[0]), context[1][1], "stack[0]");
        assertEq(kvs.length, 0, "kvs length");
    }

    /// Test the eval of context opcode parsed from a string. This tests OOB i.
    /// forge-config: default.fuzz.runs = 100
    function testOpContextEvalOOBi(bytes32[] memory context0) external {
        bytes32[][] memory context = new bytes32[][](1);
        context[0] = context0;
        bytes memory bytecode = I_DEPLOYER.parse2("_: context<1 0>();");

        vm.expectRevert(stdError.indexOOBError);
        I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: FullyQualifiedNamespace.wrap(0),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: context,
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );
    }

    /// Test the eval of context opcode parsed from a string. This tests OOB j.
    function testOpContextEvalOOBj(bytes32 v) external {
        bytes32[][] memory context = new bytes32[][](1);
        bytes32[] memory context0 = new bytes32[](1);
        context0[0] = v;
        bytes memory bytecode = I_DEPLOYER.parse2("_: context<0 1>();");

        vm.expectRevert(stdError.indexOOBError);
        I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: FullyQualifiedNamespace.wrap(0),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: context,
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );
    }

    /// Test that accessing context[i][0] reverts when the inner array is empty.
    function testOpContextEvalEmptyInnerArray() external {
        bytes32[][] memory context = new bytes32[][](1);
        context[0] = new bytes32[](0);
        bytes memory bytecode = I_DEPLOYER.parse2("_: context<0 0>();");

        vm.expectRevert(stdError.indexOOBError);
        I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: FullyQualifiedNamespace.wrap(0),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: context,
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );
    }

    /// Test context access at maximum row index (i = 255).
    function testOpContextEvalMaxI() external view {
        bytes32[][] memory context = new bytes32[][](256);
        for (uint256 k = 0; k < 256; k++) {
            context[k] = new bytes32[](1);
        }
        context[255][0] = bytes32(uint256(42));
        bytes memory bytecode = I_DEPLOYER.parse2("_: context<255 0>();");

        (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: FullyQualifiedNamespace.wrap(0),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: context,
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );
        assertEq(stack.length, 1, "stack length");
        assertEq(StackItem.unwrap(stack[0]), bytes32(uint256(42)), "stack[0]");
        assertEq(kvs.length, 0, "kvs length");
    }

    /// Test context access at maximum column index (j = 255).
    function testOpContextEvalMaxJ() external view {
        bytes32[][] memory context = new bytes32[][](1);
        context[0] = new bytes32[](256);
        context[0][255] = bytes32(uint256(99));
        bytes memory bytecode = I_DEPLOYER.parse2("_: context<0 255>();");

        (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: FullyQualifiedNamespace.wrap(0),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: context,
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );
        assertEq(stack.length, 1, "stack length");
        assertEq(StackItem.unwrap(stack[0]), bytes32(uint256(99)), "stack[0]");
        assertEq(kvs.length, 0, "kvs length");
    }

    function testOpContextOneInput() external {
        checkBadInputs("_: context<0 0>(0);", 1, 0, 1);
    }

    function testOpContextTwoInputs() external {
        checkBadInputs("_: context<0 0>(0 0);", 2, 0, 2);
    }

    function testOpContextZeroOutputs() external {
        checkBadOutputs(": context<0 0>();", 0, 1, 0);
    }

    function testOpContextTwoOutputs() external {
        checkBadOutputs("_ _: context<0 0>();", 0, 1, 2);
    }
}
