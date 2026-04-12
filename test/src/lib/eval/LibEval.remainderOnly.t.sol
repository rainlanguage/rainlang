// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainlangExpressionDeployerDeploymentTest} from "test/abstract/RainlangExpressionDeployerDeploymentTest.sol";
import {LibInterpreterState, InterpreterState} from "../../../../src/lib/state/LibInterpreterState.sol";
import {LibAllStandardOps} from "../../../../src/lib/op/LibAllStandardOps.sol";
import {LibEval} from "../../../../src/lib/eval/LibEval.sol";
import {MemoryKV} from "rain.lib.memkv/lib/LibMemoryKV.sol";
import {
    IInterpreterStoreV3,
    FullyQualifiedNamespace
} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

/// @title LibEvalRemainderOnlyTest
/// @notice Tests that the evalLoop remainder path correctly dispatches
/// opcodes when the total opcode count is less than 8, so the main
/// 8-at-a-time loop never executes.
contract LibEvalRemainderOnlyTest is RainlangExpressionDeployerDeploymentTest {
    /// 7 constant opcodes: all handled by the remainder loop (7 < 8, so the
    /// main loop body is never entered). Fuzz the constant values to verify
    /// they flow through correctly.
    function testEvalLoopRemainderOnlySeven(
        bytes32 c0,
        bytes32 c1,
        bytes32 c2,
        bytes32 c3,
        bytes32 c4,
        bytes32 c5,
        bytes32 c6
    ) external view {
        // 7 distinct hex literals produce 7 constant opcodes.
        (bytes memory bytecode,) = I_PARSER.unsafeParse(bytes("_ _ _ _ _ _ _: 0xaa 0xbb 0xcc 0xdd 0xee 0xff 0x11;"));

        bytes32[] memory constants = new bytes32[](7);
        constants[0] = c0;
        constants[1] = c1;
        constants[2] = c2;
        constants[3] = c3;
        constants[4] = c4;
        constants[5] = c5;
        constants[6] = c6;

        StackItem[][] memory stacks = new StackItem[][](1);
        stacks[0] = new StackItem[](7);

        InterpreterState memory state = InterpreterState(
            LibInterpreterState.stackBottoms(stacks),
            constants,
            0,
            MemoryKV.wrap(0),
            FullyQualifiedNamespace.wrap(0),
            IInterpreterStoreV3(address(0)),
            new bytes32[][](0),
            bytecode,
            LibAllStandardOps.opcodeFunctionPointers()
        );

        (StackItem[] memory outputs, bytes32[] memory kvs) = LibEval.eval4(state, new StackItem[](0), type(uint256).max);

        assertEq(outputs.length, 7);
        // Stack outputs are top-first: last pushed constant is first output.
        assertEq(StackItem.unwrap(outputs[0]), c6);
        assertEq(StackItem.unwrap(outputs[1]), c5);
        assertEq(StackItem.unwrap(outputs[2]), c4);
        assertEq(StackItem.unwrap(outputs[3]), c3);
        assertEq(StackItem.unwrap(outputs[4]), c2);
        assertEq(StackItem.unwrap(outputs[5]), c1);
        assertEq(StackItem.unwrap(outputs[6]), c0);
        assertEq(kvs.length, 0);
    }
}
