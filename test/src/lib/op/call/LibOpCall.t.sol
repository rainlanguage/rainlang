// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    FullyQualifiedNamespace,
    OperandV2,
    SourceIndexV2,
    EvalV4,
    StackItem
} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {OpTest} from "test/abstract/OpTest.sol";
import {BytecodeTest} from "rain.interpreter.interface/../test/abstract/BytecodeTest.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {LibOpCall} from "../../../../../src/lib/op/call/LibOpCall.sol";
import {CallOutputsExceedSource, CallInputsMismatchSource} from "../../../../../src/error/ErrIntegrity.sol";
import {LibBytecode, SourceIndexOutOfBounds} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";
import {BadOpInputsLength} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {STACK_TRACER} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";

/// @title LibOpCallTest
/// @notice Test the LibOpCall library that includes the "call" word.
contract LibOpCallTest is OpTest, BytecodeTest {
    function integrityExternal(IntegrityCheckState memory state, OperandV2 operand) external pure {
        LibOpCall.integrity(state, operand);
    }

    /// outputs is extracted via an unmasked right shift (>> 0x14). If bits
    /// above position 23 are set, the shift reads them as part of outputs.
    /// With the mask (& 0x0F), only bits 20-23 contribute. This test
    /// crafts an operand with a stray bit at position 24 and verifies
    /// integrity sees the correct 4-bit outputs value, not the inflated one.
    function testOpCallIntegrityOutputsMasked() external pure {
        // Build minimal bytecode: 1 source, 0 ops, 1 stack allocation,
        // 1 input, 1 output. Source 0 at offset 0.
        bytes memory bytecode = hex"01" // 1 source
            hex"0000" // offset 0
            hex"00" // 0 ops
            hex"01" // 1 stack alloc
            hex"01" // 1 input
            hex"01"; // 1 output

        IntegrityCheckState memory state;
        state.bytecode = bytecode;

        // Operand: sourceIndex = 0, inputs = 1 (bits 16-19), outputs = 1
        // (bits 20-23), PLUS a stray bit at position 24.
        // Without mask: outputs = (0x11_0000 >> 20) = 0x11 = 17.
        // With mask: outputs = 0x11 & 0x0F = 1.
        uint256 raw = (1 << 24) | (1 << 20) | (1 << 16) | 0;
        OperandV2 operand = OperandV2.wrap(bytes32(raw));

        // If the mask is missing, outputs = 17 > sourceOutputs = 1,
        // causing CallOutputsExceedSource. With the mask, outputs = 1
        // and integrity passes.
        (uint256 calcInputs, uint256 calcOutputs) = LibOpCall.integrity(state, operand);
        assertEq(calcInputs, 1, "inputs");
        assertEq(calcOutputs, 1, "outputs should be masked to 4 bits");
    }

    /// The operand encodes inputs at bits 16-19, but integrity() returns
    /// sourceInputs from the bytecode without comparing. If the operand
    /// says 3 inputs but the source expects 1, integrity must revert
    /// with CallInputsMismatchSource.
    function testOpCallIntegrityInputsMismatch() external {
        // Build minimal bytecode: 1 source, 0 ops, 1 stack allocation,
        // 1 input, 1 output.
        bytes memory bytecode = hex"01" // 1 source
            hex"0000" // offset 0
            hex"00" // 0 ops
            hex"01" // 1 stack alloc
            hex"01" // 1 input
            hex"01"; // 1 output

        IntegrityCheckState memory state;
        state.bytecode = bytecode;

        // Operand: sourceIndex = 0, inputs = 3 (bits 16-19), outputs = 1
        // (bits 20-23). Source expects 1 input but operand says 3.
        OperandV2 operand = OperandV2.wrap(bytes32(uint256(1 << 20 | 3 << 16)));

        vm.expectRevert(abi.encodeWithSelector(CallInputsMismatchSource.selector, 3, 1));
        this.integrityExternal(state, operand);
    }

    /// Directly test the integrity logic of LibOpCall. This tests that if the
    /// outputs in the operand exceed the outputs available from the source, then
    /// the call will revert.
    function testOpCallIntegrityTooManyOutputs(
        IntegrityCheckState memory state,
        uint256 outputs,
        uint8 sourceCount,
        bytes32 seed
    ) external {
        conformBytecode(state.bytecode, sourceCount, seed);

        uint256 sourcePosition = randomSourcePosition(state.bytecode, seed);
        uint256 sourceInputs = uint8(state.bytecode[sourcePosition + 2]);
        uint256 sourceOutputs = uint8(state.bytecode[sourcePosition + 3]);
        vm.assume(sourceOutputs < 0x0F);
        vm.assume(sourceInputs <= 0x0F);
        outputs = bound(outputs, sourceOutputs + 1, 0x0F);

        uint256 sourceIndex = randomSourceIndex(state.bytecode, seed);
        assertTrue(sourceIndex <= type(uint16).max);

        // Use sourceInputs so the inputs check passes; only outputs should fail.
        //forge-lint: disable-next-line(unsafe-typecast)
        OperandV2 operand = LibOperand.build(uint8(sourceInputs), uint8(outputs), uint16(sourceIndex));
        vm.expectRevert(abi.encodeWithSelector(CallOutputsExceedSource.selector, sourceOutputs, outputs));
        this.integrityExternal(state, operand);
    }

    /// Directly test the integrity logic of LibOpCall. This tests that if the
    /// source index in the operand is outside the source count of the bytecode,
    /// this will revert as `SourceIndexOutOfBounds`.
    function testOpCallIntegritySourceIndexOutOfBounds(
        IntegrityCheckState memory state,
        uint256 inputs,
        uint256 outputs,
        uint256 sourceCount,
        uint256 sourceIndex,
        bytes32 seed
    ) external {
        inputs = bound(inputs, 0, 0x0F);
        outputs = bound(outputs, 0, 0x0F);

        conformBytecode(state.bytecode, sourceCount, seed);
        sourceCount = LibBytecode.sourceCount(state.bytecode);

        sourceIndex = bound(sourceIndex, sourceCount, type(uint16).max);

        // Bounds ensure typecast is safe.
        // forge-lint: disable-next-line(unsafe-typecast)
        OperandV2 operand = LibOperand.build(uint8(inputs), uint8(outputs), uint16(sourceIndex));
        vm.expectRevert(abi.encodeWithSelector(SourceIndexOutOfBounds.selector, sourceIndex, state.bytecode));
        this.integrityExternal(state, operand);
    }

    /// Directly test the integrity logic of LibOpCall. This tests that if the
    /// outputs in the operand are within the bounds set by the source, then the
    /// inputs is always specified by the source (callee), and the outputs are
    /// always specified by the operand (caller).
    function testOpCallIntegrityIO(IntegrityCheckState memory state, uint256 outputs, uint8 sourceCount, bytes32 seed)
        external
        pure
    {
        conformBytecode(state.bytecode, sourceCount, seed);

        uint256 sourcePosition = randomSourcePosition(state.bytecode, seed);
        uint256 sourceInputs = uint8(state.bytecode[sourcePosition + 2]);
        uint256 sourceOutputs = uint8(state.bytecode[sourcePosition + 3]);
        vm.assume(sourceInputs <= 0x0F);
        outputs = bound(outputs, 0, sourceOutputs > 0x0F ? 0x0F : sourceOutputs);

        uint256 sourceIndex = randomSourceIndex(state.bytecode, seed);
        assertTrue(sourceIndex <= type(uint8).max);

        // Use sourceInputs so the inputs check passes.
        // forge-lint: disable-next-line(unsafe-typecast)
        OperandV2 operand = LibOperand.build(uint8(sourceInputs), uint8(outputs), uint16(sourceIndex));
        (uint256 calcInputs, uint256 calcOutputs) = LibOpCall.integrity(state, operand);
        assertEq(calcInputs, sourceInputs, "inputs");
        assertEq(calcOutputs, outputs, "outputs");
    }

    /// Boilerplate for testing that a source does not exist.
    function checkSourceDoesNotExist(bytes memory rainlang, uint256 sourceIndex, bytes memory bytecode) internal {
        checkUnhappyParse2(rainlang, abi.encodeWithSelector(SourceIndexOutOfBounds.selector, sourceIndex, bytecode));
    }

    /// Test that the eval of a call into a source that doesn't exist reverts
    /// upon deploy.
    function testOpCallRunSourceDoesNotExist() external {
        // 0 inputs and outputs different source indexes.
        checkSourceDoesNotExist(": call<1>();", 1, hex"010000010000000b000001");
        checkSourceDoesNotExist(": call<2>();", 2, hex"010000010000000b000002");
        // 1 input and 0 outputs different source indexes.
        checkSourceDoesNotExist(": call<1>(1);", 1, hex"01000002010000011000000b010001");
        checkSourceDoesNotExist(": call<2>(1);", 2, hex"01000002010000011000000b010002");
        // 0 inputs and 1 output different source indexes.
        checkSourceDoesNotExist("_: call<1>();", 1, hex"010000010100010b100001");
        checkSourceDoesNotExist("_: call<2>();", 2, hex"010000010100010b100002");
        // Several inputs and outputs different source indexes.
        checkSourceDoesNotExist("a b: call<1>(10 5);", 1, hex"0100000302000201100001011000000b220001");
        checkSourceDoesNotExist("a b: call<2>(10 5);", 2, hex"0100000302000201100001011000000b220002");
        // Multiple sources.
        checkSourceDoesNotExist(": call<2>();:;", 2, hex"0200000008010000000b00000200000000");
        checkSourceDoesNotExist(": call<3>();:;", 3, hex"0200000008010000000b00000300000000");
    }

    struct ExpectedTrace {
        uint256 parentSourceIndex;
        uint256 sourceIndex;
        StackItem[] stack;
    }

    function checkCallTraces(bytes memory rainlang, ExpectedTrace[] memory traces) internal {
        for (uint256 i = 0; i < traces.length; ++i) {
            vm.expectCall(
                STACK_TRACER,
                abi.encodePacked(
                    bytes2(uint16(traces[i].parentSourceIndex)), bytes2(uint16(traces[i].sourceIndex)), traces[i].stack
                ),
                1
            );
        }
        bytes memory bytecode = I_DEPLOYER.parse2(rainlang);
        (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: FullyQualifiedNamespace.wrap(0),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: new bytes32[][](0),
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );
        (stack, kvs);
    }

    function testCallTraceOuterOnly() external {
        ExpectedTrace[] memory traces = new ExpectedTrace[](1);
        traces[0].sourceIndex = 0;
        traces[0].stack = new StackItem[](1);
        traces[0].stack[0] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));
        checkCallTraces("_: 1;", traces);
    }

    function testCallTraceInnerOnly() external {
        ExpectedTrace[] memory traces = new ExpectedTrace[](2);
        traces[0].sourceIndex = 0;
        traces[0].stack = new StackItem[](0);
        traces[1].sourceIndex = 1;
        traces[1].stack = new StackItem[](1);
        traces[1].stack[0] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));
        checkCallTraces(":call<1>();_:1;", traces);
    }

    function testCallTraceOuterAndInner() external {
        ExpectedTrace[] memory traces = new ExpectedTrace[](2);
        traces[0].sourceIndex = 0;
        traces[0].stack = new StackItem[](1);
        traces[0].stack[0] =
            StackItem.wrap(Float.unwrap(LibDecimalFloat.add(LibDecimalFloat.FLOAT_ONE, LibDecimalFloat.FLOAT_ONE)));
        traces[1].sourceIndex = 1;
        traces[1].stack = new StackItem[](1);
        traces[1].stack[0] = StackItem.wrap(Float.unwrap(LibDecimalFloat.FLOAT_ONE));
        checkCallTraces("_:add(call<1>() 1);_:1;", traces);
    }

    function testCallTraceOuterAndTwoInner() external {
        Float ten = LibDecimalFloat.packLossless(10, 0);
        Float eleven = LibDecimalFloat.add(ten, LibDecimalFloat.FLOAT_ONE);
        Float twelve = LibDecimalFloat.add(eleven, LibDecimalFloat.FLOAT_ONE);
        ExpectedTrace[] memory traces = new ExpectedTrace[](3);
        traces[0].sourceIndex = 0;
        traces[0].stack = new StackItem[](1);
        traces[0].stack[0] = StackItem.wrap(Float.unwrap(twelve));
        traces[1].parentSourceIndex = 0;
        traces[1].sourceIndex = 1;
        traces[1].stack = new StackItem[](2);
        traces[1].stack[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.FLOAT_TWO));
        traces[1].stack[0] = StackItem.wrap(Float.unwrap(eleven));
        traces[2].parentSourceIndex = 1;
        traces[2].sourceIndex = 2;
        traces[2].stack = new StackItem[](1);
        traces[2].stack[0] = StackItem.wrap(Float.unwrap(ten));
        checkCallTraces("_:add(call<1>(2) 1);two:,_:add(call<2>() 1);_:10;", traces);
    }

    /// Boilerplate for checking the stack and kvs of a call.
    function checkCallRun(bytes memory rainlang, StackItem[] memory stack, bytes32[] memory kvs) internal view {
        bytes memory bytecode = I_DEPLOYER.parse2(rainlang);
        (StackItem[] memory actualStack, bytes32[] memory actualKVs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: FullyQualifiedNamespace.wrap(0),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: new bytes32[][](0),
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );
        assertEq(actualStack.length, stack.length, "stack length");
        for (uint256 i = 0; i < stack.length; i++) {
            assertTrue(
                LibDecimalFloat.eq(
                    Float.wrap(StackItem.unwrap(actualStack[i])), Float.wrap(StackItem.unwrap(stack[i]))
                ),
                "stack[i]"
            );
        }
        assertEq(actualKVs.length, kvs.length, "kvs length");
        for (uint256 i = 0; i < kvs.length; i++) {
            assertTrue(LibDecimalFloat.eq(Float.wrap(actualKVs[i]), Float.wrap(kvs[i])), "kvs[i]");
        }
    }

    /// Test the eval of call to see various stacks.
    function testOpCallRunNoIO() external view {
        // Check evals that result in no stack or kvs.
        StackItem[] memory stack = new StackItem[](0);
        bytes32[] memory kvs = new bytes32[](0);
        // 0 IO, call noop.
        checkCallRun(":call<1>();:;", stack, kvs);
        // Single input and no outputs.
        checkCallRun(":call<1>(10);ten:;", stack, kvs);

        // Check evals that result in a stack of one item but no kvs.
        stack = new StackItem[](1);
        // Single input and single output.
        stack[0] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(10, 0)));
        checkCallRun("ten:call<1>(10);ten:;", stack, kvs);
        // zero input single output.
        checkCallRun("ten:call<1>();ten:10;", stack, kvs);
        // Two inputs and one output.
        stack[0] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(12, 0)));
        checkCallRun("a: call<1>(10 11); ten eleven:,a b c:ten eleven 12;", stack, kvs);

        // Check evals that result in a stack of two items but no kvs.
        stack = new StackItem[](2);
        // Order dependent inputs and outputs.
        stack[0] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(9, 0)));
        stack[1] = StackItem.wrap(
            Float.unwrap(LibDecimalFloat.div(LibDecimalFloat.packLossless(10, 0), LibDecimalFloat.packLossless(5, 0)))
        );
        checkCallRun("a b: call<1>(10 5); ten five:, a b: div(ten five) 9;", stack, kvs);

        // One input two outputs.
        stack[0] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(11, 0)));
        stack[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(10, 0)));
        checkCallRun("a b: call<1>(10); ten:,a b:ten 11;", stack, kvs);

        // Can call something with no IO purely for the kv side effects.
        stack = new StackItem[](0);
        kvs = new bytes32[](2);
        kvs[0] = Float.unwrap(LibDecimalFloat.packLossless(10, 0));
        kvs[1] = Float.unwrap(LibDecimalFloat.packLossless(11, 0));
        checkCallRun(":call<1>();:set(10 11);", stack, kvs);

        // Can call for side effects and also get a stack based on IO.
        stack = new StackItem[](1);
        stack[0] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(10, 0)));
        checkCallRun("a:call<1>(9);nine:,:set(10 11),ret:add(nine 1);", stack, kvs);

        // Can call a few different things without a final stack.
        stack = new StackItem[](0);
        kvs = new bytes32[](0);
        checkCallRun(":call<1>();one two three: 1 2 3, :call<2>();five six: 5 6;", stack, kvs);
    }

    /// Test that call works with maximum inputs (15) and maximum outputs (15)
    /// simultaneously, exercising the boundary of the 4-bit operand fields.
    function testOpCallRunMaxInputsMaxOutputs() external view {
        StackItem[] memory stack = new StackItem[](15);
        for (uint256 i = 0; i < 15; i++) {
            // Outputs are read from top of callee stack, so the last input
            // (15) is returned first as stack[0].
            //forge-lint: disable-next-line(unsafe-typecast)
            stack[i] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(int256(15 - i), 0)));
        }
        bytes32[] memory kvs = new bytes32[](0);
        checkCallRun(
            "a b c d e f g h i j k l m n o: call<1>(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15); "
            "v1 v2 v3 v4 v5 v6 v7 v8 v9 v10 v11 v12 v13 v14 v15:;",
            stack,
            kvs
        );
    }

    /// Boilerplate to check a generic runtime error happens upon recursion.
    function checkCallRunRecursive(bytes memory rainlang) internal {
        bytes memory bytecode = I_DEPLOYER.parse2(rainlang);
        // But it will unconditionally happen at runtime.
        vm.expectRevert();
        (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: FullyQualifiedNamespace.wrap(0),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: new bytes32[][](0),
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );
        (stack, kvs);
    }

    /// Test that recursive calls are a (very gas intensive) runtime error.
    function testOpCallRunRecursive() external {
        // Simple call self.
        checkCallRunRecursive(":call<0>();");
        // Ping pong between two calls.
        checkCallRunRecursive(":call<1>();:call<0>();");
        // If is eager so doesn't help.
        checkCallRunRecursive("a:call<1>(1);do-call:,a:if(do-call call<1>(0) 5);");
    }

    /// Test a mismatch in the inputs from caller and callee.
    function testOpCallRunInputsMismatch() external {
        vm.expectRevert(abi.encodeWithSelector(CallInputsMismatchSource.selector, 2, 1));
        bytes memory bytecode = I_DEPLOYER.parse2("a: call<1>(10 11); ten:,a b c:ten 11 12;");
        (bytecode);
    }

    /// Test a mismatch in the outputs from caller and callee.
    function testOpCallRunOutputsMismatch() external {
        vm.expectRevert(abi.encodeWithSelector(CallOutputsExceedSource.selector, 3, 4));
        bytes memory bytecode = I_DEPLOYER.parse2("ten eleven a b: call<1>(10 11); ten eleven:,a:9;");
        (bytecode);
    }
}
