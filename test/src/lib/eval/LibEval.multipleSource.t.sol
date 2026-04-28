// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainlangExpressionDeployerDeploymentTest} from "test/abstract/RainlangExpressionDeployerDeploymentTest.sol";
import {StateNamespace} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";
import {EvalV4, SourceIndexV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibNamespace} from "rain.interpreter.interface/lib/ns/LibNamespace.sol";

contract LibEvalMultipleSourceTest is RainlangExpressionDeployerDeploymentTest {
    /// Evaluating sourceIndex 1 of a two-source expression must use the
    /// second source's bytecode.
    function testEvalSourceIndex1() external view {
        // Source 0: outputs 1, source 1: outputs 2.
        bytes memory bytecode = I_DEPLOYER.parse2("_: 1;_: 2, _: 3;");
        (StackItem[] memory stack,) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: LibNamespace.qualifyNamespace(StateNamespace.wrap(0), address(this)),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(1),
                context: new bytes32[][](0),
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );
        assertEq(stack.length, 2);
    }

    /// Source 0 and source 1 produce independent results — evaluating each
    /// returns only that source's outputs.
    function testEvalSourceIndex0VsIndex1() external view {
        bytes memory bytecode = I_DEPLOYER.parse2("_: 0x01;_: 0x02, _: 0x03;");

        (StackItem[] memory stack0,) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: LibNamespace.qualifyNamespace(StateNamespace.wrap(0), address(this)),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: new bytes32[][](0),
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );
        assertEq(stack0.length, 1);
        assertEq(StackItem.unwrap(stack0[0]), bytes32(uint256(1)));

        (StackItem[] memory stack1,) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: LibNamespace.qualifyNamespace(StateNamespace.wrap(0), address(this)),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(1),
                context: new bytes32[][](0),
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );
        assertEq(stack1.length, 2);
        assertEq(StackItem.unwrap(stack1[0]), bytes32(uint256(3)));
        assertEq(StackItem.unwrap(stack1[1]), bytes32(uint256(2)));
    }
}
