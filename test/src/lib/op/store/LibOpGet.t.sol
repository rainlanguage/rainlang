// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {LibMemoryKV, MemoryKV, MemoryKVVal, MemoryKVKey} from "rain.lib.memkv/lib/LibMemoryKV.sol";
import {LibPointer, Pointer} from "rain.solmem/lib/LibPointer.sol";
import {LibBytes32Array} from "rain.solmem/lib/LibBytes32Array.sol";

import {OpTest} from "test/abstract/OpTest.sol";
import {LibOpGet} from "../../../../../src/lib/op/store/LibOpGet.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {StateNamespace} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";

contract LibOpGetTest is OpTest {
    using LibMemoryKV for MemoryKV;
    using LibPointer for Pointer;

    /// Directly test the integrity logic of LibOpGet. The inputs are always
    /// 1 and the outputs are always 1.
    function testLibOpGetIntegrity(IntegrityCheckState memory state, uint8 inputs, uint8 outputs, uint16 operandData)
        public
        pure
    {
        inputs = uint8(bound(inputs, 1, 0x0F));
        outputs = uint8(bound(outputs, 1, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpGet.integrity(state, LibOperand.build(inputs, outputs, operandData));
        assertEq(calcInputs, 1, "inputs");
        assertEq(calcOutputs, 1, "outputs");
    }

    /// Test the eval of `get` opcode parsed from a string. Tests zero inputs.
    function testLibOpGetEvalZeroInputs() external {
        checkBadInputs("_:get();", 0, 1, 0);
    }

    /// Directly test the runtime logic of LibOpGet.
    /// Test that if the key is not in the store or state the value is 0.
    function testLibOpGetRunUnset(bytes32 key, uint16 operandData) public view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        OperandV2 operand = LibOperand.build(1, 1, operandData);
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = StackItem.wrap(key);
        state.stateKV = MemoryKV.wrap(0);

        uint256 calcOutputs = opReferenceCheckIntegrity(LibOpGet.integrity, operand, state.constants, inputs);
        ReferenceCheckPointers memory pointers = opReferenceCheckPointers(inputs, calcOutputs);
        assertEq(MemoryKV.unwrap(state.stateKV), 0);
        pointers.actualStackTopAfter = LibOpGet.run(state, operand, pointers.stackTop);

        bytes32 getValue = pointers.actualStackTopAfter.unsafeReadWord();
        assertEq(getValue, 0, "getValue");

        // Get will put a value of 0 in the state for the key if it's not
        // previously set.
        (uint256 exists, MemoryKVVal actualValue) = state.stateKV.get(MemoryKVKey.wrap(key));
        assertEq(exists, 1, "exists");
        assertEq(MemoryKVVal.unwrap(actualValue), 0, "value");

        bytes32[] memory kvs = state.stateKV.toBytes32Array();
        assertEq(kvs.length, 2, "kvs.length");

        state.stateKV = MemoryKV.wrap(0);
        opReferenceCheckExpectations(state, operand, LibOpGet.referenceFn, pointers, inputs, calcOutputs);
    }

    /// Directly test the runtime logic of LibOpGet.
    /// Test that if the key is in the store the value is fetched from the store.
    function testLibOpGetRunStore(bytes32 key, bytes32 value, uint16 operandData) public {
        InterpreterState memory state = opTestDefaultInterpreterState();
        OperandV2 operand = LibOperand.build(1, 1, operandData);
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = StackItem.wrap(key);
        state.stateKV = MemoryKV.wrap(0);
        state.store.set(StateNamespace.wrap(0), LibBytes32Array.arrayFrom(key, value));

        uint256 calcOutputs = opReferenceCheckIntegrity(LibOpGet.integrity, operand, state.constants, inputs);
        ReferenceCheckPointers memory pointers = opReferenceCheckPointers(inputs, calcOutputs);
        assertEq(MemoryKV.unwrap(state.stateKV), 0);
        pointers.actualStackTopAfter = LibOpGet.run(state, operand, pointers.stackTop);

        bytes32 getValue = pointers.actualStackTopAfter.unsafeReadWord();
        assertEq(getValue, value, "getValue");

        // Get will put a value of 0 in the state for the key if it's not
        // previously set.
        (uint256 exists, MemoryKVVal actualValue) = state.stateKV.get(MemoryKVKey.wrap(key));
        assertEq(exists, 1, "exists");
        assertEq(MemoryKVVal.unwrap(actualValue), value, "value");

        bytes32[] memory kvs = state.stateKV.toBytes32Array();
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], key, "kvs[0]");
        assertEq(kvs[1], value, "kvs[1]");

        state.stateKV = MemoryKV.wrap(0);
        opReferenceCheckExpectations(state, operand, LibOpGet.referenceFn, pointers, inputs, calcOutputs);
    }

    /// Directly test the runtime logic of LibOpGet.
    /// Test that if the key is in the state the value is fetched from the state.
    function testLibOpGetRunState(bytes32 key, bytes32 value, uint16 operandData) public view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        OperandV2 operand = LibOperand.build(1, 1, operandData);
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = StackItem.wrap(key);
        state.stateKV = MemoryKV.wrap(0);
        state.stateKV = state.stateKV.set(MemoryKVKey.wrap(key), MemoryKVVal.wrap(value));

        uint256 calcOutputs = opReferenceCheckIntegrity(LibOpGet.integrity, operand, state.constants, inputs);
        ReferenceCheckPointers memory pointers = opReferenceCheckPointers(inputs, calcOutputs);
        pointers.actualStackTopAfter = LibOpGet.run(state, operand, pointers.stackTop);

        bytes32 getValue = pointers.actualStackTopAfter.unsafeReadWord();
        assertEq(getValue, value, "getValue");

        // Get will put a value of 0 in the state for the key if it's not
        // previously set.
        (uint256 exists, MemoryKVVal actualValue) = state.stateKV.get(MemoryKVKey.wrap(key));
        assertEq(exists, 1, "exists");
        assertEq(MemoryKVVal.unwrap(actualValue), value, "value");

        bytes32[] memory kvs = state.stateKV.toBytes32Array();
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], key, "kvs[0]");
        assertEq(kvs[1], value, "kvs[1]");

        state.stateKV = MemoryKV.wrap(0);
        state.stateKV = state.stateKV.set(MemoryKVKey.wrap(key), MemoryKVVal.wrap(value));
        opReferenceCheckExpectations(state, operand, LibOpGet.referenceFn, pointers, inputs, calcOutputs);
    }

    /// Directly test the runtime logic of LibOpGet.
    /// Test that if the key is in the state and the store the value is fetched
    /// from the state.
    function testLibOpGetRunStateAndStore(bytes32 key, bytes32 valueStore, bytes32 valueState, uint16 operandData)
        public
    {
        InterpreterState memory state = opTestDefaultInterpreterState();
        OperandV2 operand = LibOperand.build(1, 1, operandData);
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = StackItem.wrap(key);
        state.stateKV = MemoryKV.wrap(0);
        state.stateKV = state.stateKV.set(MemoryKVKey.wrap(key), MemoryKVVal.wrap(valueState));
        state.store.set(StateNamespace.wrap(0), LibBytes32Array.arrayFrom(key, valueStore));

        uint256 calcOutputs = opReferenceCheckIntegrity(LibOpGet.integrity, operand, state.constants, inputs);
        ReferenceCheckPointers memory pointers = opReferenceCheckPointers(inputs, calcOutputs);
        pointers.actualStackTopAfter = LibOpGet.run(state, operand, pointers.stackTop);

        bytes32 getValue = pointers.actualStackTopAfter.unsafeReadWord();
        assertEq(getValue, valueState, "getValue");

        // Get will put a value of 0 in the state for the key if it's not
        // previously set.
        (uint256 exists, MemoryKVVal actualValue) = state.stateKV.get(MemoryKVKey.wrap(key));
        assertEq(exists, 1, "exists");
        assertEq(MemoryKVVal.unwrap(actualValue), valueState, "value");

        bytes32[] memory kvs = state.stateKV.toBytes32Array();
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], key, "kvs[0]");
        assertEq(kvs[1], valueState, "kvs[1]");

        state.stateKV = MemoryKV.wrap(0);
        state.stateKV = state.stateKV.set(MemoryKVKey.wrap(key), MemoryKVVal.wrap(valueState));
        opReferenceCheckExpectations(state, operand, LibOpGet.referenceFn, pointers, inputs, calcOutputs);
    }

    /// Directly test the runtime logic of LibOpGet.
    /// Test that if a value is set in the store under a different namespace
    /// to the state, then get cannot see it.
    function testLibOpGetRunStoreDifferentNamespace(bytes32 key, bytes32 value, uint16 operandData) public {
        InterpreterState memory state = opTestDefaultInterpreterState();
        OperandV2 operand = LibOperand.build(1, 1, operandData);
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = StackItem.wrap(key);
        state.stateKV = MemoryKV.wrap(0);
        state.store.set(StateNamespace.wrap(1), LibBytes32Array.arrayFrom(key, value));

        uint256 calcOutputs = opReferenceCheckIntegrity(LibOpGet.integrity, operand, state.constants, inputs);
        ReferenceCheckPointers memory pointers = opReferenceCheckPointers(inputs, calcOutputs);
        pointers.actualStackTopAfter = LibOpGet.run(state, operand, pointers.stackTop);

        bytes32 getValue = pointers.actualStackTopAfter.unsafeReadWord();
        assertEq(getValue, 0, "getValue");

        // Get will put a value of 0 in the state for the key if it's not
        // previously set.
        (uint256 exists, MemoryKVVal actualValue) = state.stateKV.get(MemoryKVKey.wrap(key));
        assertEq(exists, 1, "exists");
        assertEq(MemoryKVVal.unwrap(actualValue), 0, "value");

        bytes32[] memory kvs = state.stateKV.toBytes32Array();
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], key, "kvs[0]");
        assertEq(kvs[1], 0, "kvs[1]");

        state.stateKV = MemoryKV.wrap(0);
        opReferenceCheckExpectations(state, operand, LibOpGet.referenceFn, pointers, inputs, calcOutputs);
    }

    /// Test the eval of `get` opcode parsed from a string. Tests that if
    /// the key is not set in the store, the value is 0.
    function testLibOpGetEvalKeyNotSet() external view {
        StackItem[] memory stack;
        bytes32[] memory kvs;
        (stack, kvs) = parseAndEval("_:get(0x1234);");
        assertEq(stack.length, 1, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), 0, "stack[0]");
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], bytes32(uint256(0x1234)), "kvs[0]");
        assertEq(kvs[1], 0, "kvs[1]");

        (stack, kvs) = parseAndEval("_:get(0x1234),_:get(0x1234);");
        assertEq(stack.length, 2, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), 0, "stack[0]");
        assertEq(StackItem.unwrap(stack[1]), 0, "stack[1]");
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], bytes32(uint256(0x1234)), "kvs[0]");
        assertEq(kvs[1], 0, "kvs[1]");

        (stack, kvs) = parseAndEval("_:get(0x1234),_:get(0x5678);");
        assertEq(stack.length, 2, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), 0, "stack[0]");
        assertEq(StackItem.unwrap(stack[1]), 0, "stack[1]");
        assertEq(kvs.length, 4, "kvs.length");
        assertEq(kvs[2], bytes32(uint256(0x1234)), "kvs[0]");
        assertEq(kvs[3], 0, "kvs[1]");
        assertEq(kvs[0], bytes32(uint256(0x5678)), "kvs[2]");
        assertEq(kvs[1], 0, "kvs[3]");

        (stack, kvs) = parseAndEval("_:get(0x5678);");
        assertEq(stack.length, 1, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), 0, "stack[0]");
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], bytes32(uint256(0x5678)), "kvs[0]");
        assertEq(kvs[1], 0, "kvs[1]");

        (stack, kvs) = parseAndEval("_:get(0);");
        assertEq(stack.length, 1, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), 0, "stack[0]");
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], 0, "kvs[0]");
        assertEq(kvs[1], 0, "kvs[1]");

        (stack, kvs) = parseAndEval("_:get(uint256-max-value());");
        assertEq(stack.length, 1, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), 0, "stack[0]");
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], bytes32(type(uint256).max), "kvs[0]");
        assertEq(kvs[1], 0, "kvs[1]");
    }

    /// Test the eval of `get` opcode parsed from a string. Tests that if
    /// `set` is called prior then `get` can see it.
    function testLibOpGetEvalSetThenGet() external view {
        StackItem[] memory stack;
        bytes32[] memory kvs;

        // Set a value and get it.
        (stack, kvs) = parseAndEval(":set(0x1234 0x5678),_:get(0x1234);");
        assertEq(stack.length, 1, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), bytes32(uint256(0x5678)), "stack[0]");
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], bytes32(uint256(0x1234)), "kvs[0]");
        assertEq(kvs[1], bytes32(uint256(0x5678)), "kvs[1]");

        // Set some value then get it twice.
        (stack, kvs) = parseAndEval(":set(0x1234 0x5678),_:get(0x1234),_:get(0x1234);");
        assertEq(stack.length, 2, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), bytes32(uint256(0x5678)), "stack[0]");
        assertEq(StackItem.unwrap(stack[1]), bytes32(uint256(0x5678)), "stack[1]");
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], bytes32(uint256(0x1234)), "kvs[0]");
        assertEq(kvs[1], bytes32(uint256(0x5678)), "kvs[1]");

        // Set some value then get it and also get something unset.
        (stack, kvs) = parseAndEval(":set(0x1234 0x5678),_:get(0x1234),_:get(0x5678);");
        assertEq(stack.length, 2, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), 0, "stack[0]");
        assertEq(StackItem.unwrap(stack[1]), bytes32(uint256(0x5678)), "stack[1]");
        assertEq(kvs.length, 4, "kvs.length");
        assertEq(kvs[2], bytes32(uint256(0x1234)), "kvs[0]");
        assertEq(kvs[3], bytes32(uint256(0x5678)), "kvs[1]");
        assertEq(kvs[0], bytes32(uint256(0x5678)), "kvs[2]");
        assertEq(kvs[1], 0, "kvs[3]");

        // Set some value then get a different value.
        (stack, kvs) = parseAndEval(":set(0x1234 0x5678),_:get(0x5678);");
        assertEq(stack.length, 1, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), 0, "stack[0]");
        assertEq(kvs.length, 4, "kvs.length");
        assertEq(kvs[2], bytes32(uint256(0x1234)), "kvs[0]");
        assertEq(kvs[3], bytes32(uint256(0x5678)), "kvs[1]");
        assertEq(kvs[0], bytes32(uint256(0x5678)), "kvs[2]");
        assertEq(kvs[1], 0, "kvs[3]");

        // Set to some value then set to some other value before get.
        (stack, kvs) = parseAndEval(":set(0x1234 0x5678),:set(0x1234 0x9abc),_:get(0x1234);");
        assertEq(stack.length, 1, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), bytes32(uint256(0x9abc)), "stack[0]");
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], bytes32(uint256(0x1234)), "kvs[0]");
        assertEq(kvs[1], bytes32(uint256(0x9abc)), "kvs[1]");

        // Set two values then get one of them.
        (stack, kvs) = parseAndEval(":set(0x1234 0x5678),:set(0x5678 0x9abc),_:get(0x1234);");
        assertEq(stack.length, 1, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), bytes32(uint256(0x5678)), "stack[0]");
        assertEq(kvs.length, 4, "kvs.length");
        assertEq(kvs[2], bytes32(uint256(0x1234)), "kvs[0]");
        assertEq(kvs[3], bytes32(uint256(0x5678)), "kvs[1]");
        assertEq(kvs[0], bytes32(uint256(0x5678)), "kvs[2]");
        assertEq(kvs[1], bytes32(uint256(0x9abc)), "kvs[3]");

        // Set two values then get neither of them.
        (stack, kvs) = parseAndEval(":set(0x1234 0x5678),:set(0x5678 0x9abc),_:get(0x9abc);");
        assertEq(stack.length, 1, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), 0, "stack[0]");
        assertEq(kvs.length, 6, "kvs.length");
        assertEq(kvs[2], bytes32(uint256(0x1234)), "kvs[0]");
        assertEq(kvs[3], bytes32(uint256(0x5678)), "kvs[1]");
        assertEq(kvs[0], bytes32(uint256(0x5678)), "kvs[2]");
        assertEq(kvs[1], bytes32(uint256(0x9abc)), "kvs[3]");
        assertEq(kvs[4], bytes32(uint256(0x9abc)), "kvs[4]");
        assertEq(kvs[5], 0, "kvs[5]");
    }

    /// Test the eval of `get` opcode parsed from a string. Tests that if
    /// the key is set in the store prior to eval then `get` can see it.
    function testLibOpGetEvalStoreThenGet() external {
        StackItem[] memory stack;
        bytes32[] memory kvs;

        // Some key and value.
        bytes32 key = bytes32(uint256(0x1234));
        bytes32 value = bytes32(uint256(0x5678));
        I_STORE.set(StateNamespace.wrap(0), LibBytes32Array.arrayFrom(key, value));

        (stack, kvs) = parseAndEval("_:get(0x1234);");
        assertEq(stack.length, 1, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), value, "stack[0]");
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], key, "kvs[0]");
        assertEq(kvs[1], value, "kvs[1]");

        // Key 0 and value 0.
        key = 0;
        value = 0;
        I_STORE.set(StateNamespace.wrap(0), LibBytes32Array.arrayFrom(key, value));

        (stack, kvs) = parseAndEval("_:get(0);");
        assertEq(stack.length, 1, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), value, "stack[0]");
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], key, "kvs[0]");
        assertEq(kvs[1], value, "kvs[1]");

        // Key max and value max.
        key = bytes32(type(uint256).max);
        value = bytes32(type(uint256).max);
        I_STORE.set(StateNamespace.wrap(0), LibBytes32Array.arrayFrom(key, value));

        (stack, kvs) = parseAndEval("_:get(uint256-max-value());");
        assertEq(stack.length, 1, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), value, "stack[0]");
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], key, "kvs[0]");
        assertEq(kvs[1], value, "kvs[1]");

        // Some key and value, then some other key and value.
        key = bytes32(uint256(0x1234));
        value = bytes32(uint256(0x5678));
        I_STORE.set(StateNamespace.wrap(0), LibBytes32Array.arrayFrom(key, value));
        key = bytes32(uint256(0x9abc));
        value = bytes32(uint256(0xdef0));
        I_STORE.set(StateNamespace.wrap(0), LibBytes32Array.arrayFrom(key, value));

        (stack, kvs) = parseAndEval("_:get(0x1234);");
        assertEq(stack.length, 1, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), bytes32(uint256(0x5678)), "stack[0]");
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], bytes32(uint256(0x1234)), "kvs[0]");
        assertEq(kvs[1], bytes32(uint256(0x5678)), "kvs[1]");

        // key 0 value non-zero.
        key = 0;
        value = bytes32(uint256(0x5678));
        I_STORE.set(StateNamespace.wrap(0), LibBytes32Array.arrayFrom(key, value));

        (stack, kvs) = parseAndEval("_:get(0);");
        assertEq(stack.length, 1, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), bytes32(uint256(0x5678)), "stack[0]");
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], 0, "kvs[0]");
        assertEq(kvs[1], bytes32(uint256(0x5678)), "kvs[1]");

        // key non-zero value 0.
        key = bytes32(uint256(0x1234));
        value = 0;
        I_STORE.set(StateNamespace.wrap(0), LibBytes32Array.arrayFrom(key, value));

        (stack, kvs) = parseAndEval("_:get(0x1234);");
        assertEq(stack.length, 1, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), 0, "stack[0]");
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], bytes32(uint256(0x1234)), "kvs[0]");
        assertEq(kvs[1], 0, "kvs[1]");

        // key max value non-zero.
        key = bytes32(type(uint256).max);
        value = bytes32(uint256(0x5678));
        I_STORE.set(StateNamespace.wrap(0), LibBytes32Array.arrayFrom(key, value));

        (stack, kvs) = parseAndEval("_:get(uint256-max-value());");
        assertEq(stack.length, 1, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), bytes32(uint256(0x5678)), "stack[0]");
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], bytes32(type(uint256).max), "kvs[0]");
        assertEq(kvs[1], bytes32(uint256(0x5678)), "kvs[1]");

        // key non-zero value max.
        key = bytes32(uint256(0x1234));
        value = bytes32(type(uint256).max);
        I_STORE.set(StateNamespace.wrap(0), LibBytes32Array.arrayFrom(key, value));

        (stack, kvs) = parseAndEval("_:get(0x1234);");
        assertEq(stack.length, 1, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), bytes32(type(uint256).max), "stack[0]");
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], bytes32(uint256(0x1234)), "kvs[0]");
        assertEq(kvs[1], bytes32(type(uint256).max), "kvs[1]");
    }

    /// Test the eval of `get` opcode parsed from a string. Tests a combination
    /// of setting in the store and setting in the state with `set`.
    function testLibOpGetEvalStoreAndSetAndGet() external {
        StackItem[] memory stack;
        bytes32[] memory kvs;

        // Set a value in store then override it with set before getting.
        I_STORE.set(
            StateNamespace.wrap(0), LibBytes32Array.arrayFrom(bytes32(uint256(0x1234)), bytes32(uint256(0x5678)))
        );
        (stack, kvs) = parseAndEval(":set(0x1234 0x9abc),_:get(0x1234);");
        assertEq(stack.length, 1, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), bytes32(uint256(0x9abc)), "stack[0]");
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], bytes32(uint256(0x1234)), "kvs[0]");
        assertEq(kvs[1], bytes32(uint256(0x9abc)), "kvs[1]");

        // Set a value in store then override it with set after getting.
        I_STORE.set(
            StateNamespace.wrap(0), LibBytes32Array.arrayFrom(bytes32(uint256(0x1234)), bytes32(uint256(0x5678)))
        );
        (stack, kvs) = parseAndEval("_:get(0x1234),:set(0x1234 0x9abc),_:get(0x1234);");
        assertEq(stack.length, 2, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), bytes32(uint256(0x9abc)), "stack[0]");
        assertEq(StackItem.unwrap(stack[1]), bytes32(uint256(0x5678)), "stack[1]");
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], bytes32(uint256(0x1234)), "kvs[0]");
        assertEq(kvs[1], bytes32(uint256(0x9abc)), "kvs[1]");

        // Set a value in store then set some other value before getting each.
        I_STORE.set(
            StateNamespace.wrap(0), LibBytes32Array.arrayFrom(bytes32(uint256(0x1234)), bytes32(uint256(0x5678)))
        );
        (stack, kvs) = parseAndEval(":set(0x9abc 0xdef0),_:get(0x1234),_:get(0x9abc);");
        assertEq(stack.length, 2, "stack.length");
        assertEq(StackItem.unwrap(stack[0]), bytes32(uint256(0xdef0)), "stack[0]");
        assertEq(StackItem.unwrap(stack[1]), bytes32(uint256(0x5678)), "stack[1]");
        assertEq(kvs.length, 4, "kvs.length");
        assertEq(kvs[0], bytes32(uint256(0x1234)), "kvs[0]");
        assertEq(kvs[1], bytes32(uint256(0x5678)), "kvs[1]");
        assertEq(kvs[2], bytes32(uint256(0x9abc)), "kvs[2]");
        assertEq(kvs[3], bytes32(uint256(0xdef0)), "kvs[3]");
    }

    /// Test the eval of `get` opcode parsed from a string. Tests two inputs.
    function testLibOpGetEvalTwoInputs() external {
        checkBadInputs("_:get(0x1234 0x5678);", 2, 1, 2);
    }

    /// Test the eval of `get` opcode parsed from a string. Tests three inputs.
    function testLibOpGetEvalThreeInputs() external {
        checkBadInputs("_:get(0x1234 0x5678 0x9abc);", 3, 1, 3);
    }

    function testLibOpGetEvalZeroOutputs() external {
        checkBadOutputs(":get(0x1234);", 1, 1, 0);
    }

    function testLibOpGetEvalTwoOutputs() external {
        checkBadOutputs("_ _:get(0x1234);", 1, 1, 2);
    }

    /// Test the eval of `get` opcode parsed from a string.
    /// Tests that operands are disallowed.
    function testLibOpGetEvalOperandDisallowed() external {
        checkDisallowedOperand("_:get<0>(0x1234);");
        checkDisallowedOperand("_:get<1>(0x1234);");
        checkDisallowedOperand("_:get<2>(0x1234);");
        checkDisallowedOperand("_:get<3 1>(0x1234);");
    }
}
