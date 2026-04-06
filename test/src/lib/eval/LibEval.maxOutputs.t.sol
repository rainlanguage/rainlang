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

/// @title LibEvalMaxOutputsTest
/// @notice Tests that eval4 truncates outputs when maxOutputs < sourceOutputs.
contract LibEvalMaxOutputsTest is RainlangExpressionDeployerDeploymentTest {
    /// When maxOutputs < sourceOutputs, the returned array length must
    /// equal maxOutputs and contain the topmost stack items.
    function testMaxOutputsTruncation(uint8 maxOutputs, bytes32 c0, bytes32 c1, bytes32 c2) external view {
        maxOutputs = uint8(bound(maxOutputs, 0, 2));

        // unsafeParse assigns constants in encounter order: 0xaa=0, 0xbb=1, 0xcc=2.
        // The assertions below depend on this ordering (stack top is c2).
        (bytes memory bytecode,) = I_PARSER.unsafeParse(bytes("_ _ _: 0xaa 0xbb 0xcc;"));

        bytes32[] memory constants = new bytes32[](3);
        constants[0] = c0;
        constants[1] = c1;
        constants[2] = c2;

        StackItem[][] memory stacks = new StackItem[][](1);
        stacks[0] = new StackItem[](3);

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

        (StackItem[] memory outputs, bytes32[] memory kvs) =
            LibEval.eval4(state, new StackItem[](0), uint256(maxOutputs));

        assertEq(outputs.length, uint256(maxOutputs));
        if (maxOutputs >= 1) assertEq(StackItem.unwrap(outputs[0]), c2);
        if (maxOutputs >= 2) assertEq(StackItem.unwrap(outputs[1]), c1);
        assertEq(kvs.length, 0);
    }
}
