// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {LibMemoryKV, MemoryKV, MemoryKVVal, MemoryKVKey} from "rain.lib.memkv/lib/LibMemoryKV.sol";

import {OpTest} from "test/abstract/OpTest.sol";
import {LibOpSet} from "../../../../../src/lib/op/store/LibOpSet.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";

contract LibOpSetTest is OpTest {
    using LibMemoryKV for MemoryKV;

    /// Directly test the integrity logic of LibOpSet. The inputs are always
    /// 2 and the outputs are always 0.
    function testLibOpSetIntegrity(IntegrityCheckState memory state, uint8 inputs, uint8 outputs, uint16 operandData)
        public
        pure
    {
        inputs = uint8(bound(inputs, 0, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpSet.integrity(state, LibOperand.build(inputs, outputs, operandData));
        assertEq(calcInputs, 2, "inputs");
        assertEq(calcOutputs, 0, "outputs");
    }

    /// Directly test the runtime logic of LibOpSet.
    function testLibOpSet(bytes32 key, bytes32 value) public view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        OperandV2 operand = OperandV2.wrap(bytes32(uint256(2) << 0x10));
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(key);
        inputs[1] = StackItem.wrap(value);
        state.stateKV = MemoryKV.wrap(0);

        uint256 calcOutputs = opReferenceCheckIntegrity(LibOpSet.integrity, operand, state.constants, inputs);
        ReferenceCheckPointers memory pointers = opReferenceCheckPointers(inputs, calcOutputs);
        assertEq(MemoryKV.unwrap(state.stateKV), 0);
        pointers.actualStackTopAfter = LibOpSet.run(state, operand, pointers.stackTop);

        (uint256 exists, MemoryKVVal actualValue) = state.stateKV.get(MemoryKVKey.wrap(key));
        assertEq(exists, 1, "exists");
        assertEq(MemoryKVVal.unwrap(actualValue), value, "value");

        bytes32[] memory kvs = state.stateKV.toBytes32Array();
        assertEq(kvs.length, 2, "kvs.length");
        assertEq(kvs[0], key, "kvs[0]");
        assertEq(kvs[1], value, "kvs[1]");

        state.stateKV = MemoryKV.wrap(0);
        opReferenceCheckExpectations(state, operand, LibOpSet.referenceFn, pointers, inputs, calcOutputs);
    }

    /// Test the eval of `set` opcode parsed from a string. Tests zero inputs.
    function testLibOpSetEvalZeroInputs() external {
        checkBadInputs(":set();", 0, 2, 0);
    }

    /// Test the eval of `set` opcode parsed from a string. Tests two inputs.
    function testLibOpSetEvalTwoInputs() external view {
        bytes32[] memory expectedKVs = new bytes32[](2);
        expectedKVs[0] = bytes32(uint256(0x1234));
        expectedKVs[1] = bytes32(uint256(0x5678));
        checkHappyKVs(":set(0x1234 0x5678);", expectedKVs, "0x1234 0x5678");

        expectedKVs[0] = 0;
        expectedKVs[1] = 0;
        checkHappyKVs(":set(0 0);", expectedKVs, "0 0");

        expectedKVs[0] = bytes32(uint256(0x1234));
        expectedKVs[1] = 0;
        checkHappyKVs(":set(0x1234 0);", expectedKVs, "0x1234 0");

        expectedKVs[0] = 0;
        expectedKVs[1] = bytes32(uint256(0x5678));
        checkHappyKVs(":set(0 0x5678);", expectedKVs, "0 0x5678");

        // Setting the same key twice should overwrite the value.
        expectedKVs[0] = bytes32(uint256(0x1234));
        expectedKVs[1] = bytes32(uint256(0x9abc));
        checkHappyKVs(":set(0x1234 0x5678),:set(0x1234 0x9abc);", expectedKVs, "0x1234 0x5678 0x9abc");
    }

    /// Test the eval of `set` opcode parsed from a string. Tests setting twice.
    function testLibOpSetEvalSetTwice() external view {
        bytes32[] memory expectedKVs = new bytes32[](4);
        // The ordering of the expectedKVs is based on internal hashing not the
        // order of setting.
        expectedKVs[2] = bytes32(uint256(0x1234));
        expectedKVs[3] = bytes32(uint256(0x5678));
        expectedKVs[0] = bytes32(uint256(0x5678));
        expectedKVs[1] = bytes32(uint256(0x9abc));
        checkHappyKVs(":set(0x1234 0x5678),:set(0x5678 0x9abc);", expectedKVs, "0x1234 0x5678 0x5678 0x9abc");
    }

    /// Test the eval of `set` opcode parsed from a string. Tests one input.
    function testLibOpSetEvalOneInput() external {
        checkBadInputs(":set(0x1234);", 1, 2, 1);
    }

    /// Test the eval of `set` opcode parsed from a string. Tests three inputs.
    function testLibOpSetEvalThreeInputs() external {
        checkBadInputs(":set(0x1234 0x5678 0x9abc);", 3, 2, 3);
    }

    function testLibOpSetEvalOneOutput() external {
        checkBadOutputs("_:set(0x1234 0x5678);", 2, 0, 1);
    }

    function testLibOpSetEvalTwoOutputs() external {
        checkBadOutputs("_ _:set(0x1234 0x5678);", 2, 0, 2);
    }

    /// Test the eval of `set` opcode parsed from a string.
    /// Tests that operands are disallowed.
    function testLibOpSetEvalOperandsDisallowed() external {
        checkDisallowedOperand(":set<0>(0x1234 0x5678);");
        checkDisallowedOperand(":set<1>(0x1234 0x5678);");
        checkDisallowedOperand(":set<2>(0x1234 0x5678);");
        checkDisallowedOperand(":set<3 1>(0x1234 0x5678);");
    }
}
