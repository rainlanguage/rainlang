// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    RainlangExpressionDeployerDeploymentTest
} from "test/abstract/RainlangExpressionDeployerDeploymentTest.sol";
import {StateNamespace} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";
import {EvalV4, SourceIndexV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibNamespace} from "rain.interpreter.interface/lib/ns/LibNamespace.sol";
import {Float, LibDecimalFloat} from "rain.math.float/lib/LibDecimalFloat.sol";

/// @title RainlangInterpreterEvalNonZeroSourceIndexTest
/// @notice Tests that `eval4` correctly selects non-zero source indices.
contract RainlangInterpreterEvalNonZeroSourceIndexTest is RainlangExpressionDeployerDeploymentTest {
    using LibDecimalFloat for Float;

    /// @notice eval4 with sourceIndex = 1 MUST evaluate the second source, not
    /// the first.
    function testEvalNonZeroSourceIndex() external view {
        // Source 0 produces 42. Source 1 produces 99.
        bytes memory bytecode = I_DEPLOYER.parse2("_: 42;_: 99;");

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

        assertEq(stack.length, 1, "source 1 should produce exactly 1 output");
        Float expected = LibDecimalFloat.packLossless(99, 0);
        assertTrue(Float.wrap(StackItem.unwrap(stack[0])).eq(expected), "source 1 should return 99");
    }

    /// @notice eval4 with sourceIndex = 1 where source 1 expects inputs MUST
    /// work when correct inputs are provided.
    function testEvalNonZeroSourceIndexWithInputs() external view {
        // Source 0: no-op. Source 1: takes one input and adds 1 to it.
        bytes memory bytecode = I_DEPLOYER.parse2("_: 42;x:, _: add(x 1);");

        Float inputVal = LibDecimalFloat.packLossless(10, 0);
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = StackItem.wrap(Float.unwrap(inputVal));

        (StackItem[] memory stack,) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: LibNamespace.qualifyNamespace(StateNamespace.wrap(0), address(this)),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(1),
                context: new bytes32[][](0),
                inputs: inputs,
                stateOverlay: new bytes32[](0)
            })
        );

        assertEq(stack.length, 2, "source 1 should produce 2 outputs (1 input + 1 op)");
        Float expected = LibDecimalFloat.packLossless(11, 0);
        assertTrue(Float.wrap(StackItem.unwrap(stack[0])).eq(expected), "source 1 should return add(10, 1) = 11");
    }

    /// @notice Source index 0 and source index 1 produce different results from
    /// the same bytecode, confirming sourceIndex is respected.
    function testEvalSourceIndexSelectsCorrectSource() external view {
        bytes memory bytecode = I_DEPLOYER.parse2("_: 7;_: 13;");

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

        Float expected0 = LibDecimalFloat.packLossless(7, 0);
        Float expected1 = LibDecimalFloat.packLossless(13, 0);
        assertTrue(Float.wrap(StackItem.unwrap(stack0[0])).eq(expected0), "source 0 should return 7");
        assertTrue(Float.wrap(StackItem.unwrap(stack1[0])).eq(expected1), "source 1 should return 13");
    }
}
