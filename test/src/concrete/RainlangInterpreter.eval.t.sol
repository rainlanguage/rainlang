// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainlangExpressionDeployerDeploymentTest} from "test/abstract/RainlangExpressionDeployerDeploymentTest.sol";
import {StateNamespace} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";
import {EvalV4, SourceIndexV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibNamespace} from "rain.interpreter.interface/lib/ns/LibNamespace.sol";
import {InputsLengthMismatch} from "../../../src/error/ErrEval.sol";
import {Float, LibDecimalFloat} from "rain.math.float/lib/LibDecimalFloat.sol";

contract RainlangInterpreterEvalTest is RainlangExpressionDeployerDeploymentTest {
    using LibDecimalFloat for Float;

    /// Passing more inputs than the source expects MUST revert.
    function testInputsLengthMismatchTooMany(uint8 extraInputs) external {
        vm.assume(extraInputs > 0);

        // Source expects 0 inputs.
        bytes memory bytecode = I_DEPLOYER.parse2("_: 1;");

        StackItem[] memory inputs = new StackItem[](extraInputs);

        vm.expectRevert(abi.encodeWithSelector(InputsLengthMismatch.selector, 0, extraInputs));
        I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: LibNamespace.qualifyNamespace(StateNamespace.wrap(0), address(this)),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: new bytes32[][](0),
                inputs: inputs,
                stateOverlay: new bytes32[](0)
            })
        );
    }

    /// Passing fewer inputs than the source expects MUST revert.
    function testInputsLengthMismatchTooFew(uint8 expectedInputs, uint8 actualInputs) external {
        expectedInputs = uint8(bound(expectedInputs, 1, 15));
        vm.assume(actualInputs < expectedInputs);

        // Build rainlang with expectedInputs LHS names: "a b c ... :;"
        bytes memory rainlang = new bytes(2 * uint256(expectedInputs) + 1);
        for (uint256 i = 0; i < expectedInputs; i++) {
            // Safe: i is bounded by expectedInputs which is bounded to <= 15 by the test.
            //forge-lint: disable-next-line(unsafe-typecast)
            rainlang[i * 2] = bytes1(uint8(0x61) + uint8(i));
            if (i < uint256(expectedInputs) - 1) {
                rainlang[i * 2 + 1] = " ";
            }
        }
        rainlang[uint256(expectedInputs) * 2 - 1] = ":";
        rainlang[uint256(expectedInputs) * 2] = ";";

        bytes memory bytecode = I_DEPLOYER.parse2(rainlang);
        StackItem[] memory inputs = new StackItem[](actualInputs);

        vm.expectRevert(abi.encodeWithSelector(InputsLengthMismatch.selector, expectedInputs, actualInputs));
        I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: LibNamespace.qualifyNamespace(StateNamespace.wrap(0), address(this)),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: new bytes32[][](0),
                inputs: inputs,
                stateOverlay: new bytes32[](0)
            })
        );
    }

    /// Passing the correct number of non-zero inputs must succeed and the
    /// inputs must be usable by ops in the source.
    function testEvalWithMatchingInputs(int256 a, int256 b) external view {
        a = bound(a, -1e18, 1e18);
        b = bound(b, -1e18, 1e18);
        Float fa = LibDecimalFloat.packLossless(a, 0);
        Float fb = LibDecimalFloat.packLossless(b, 0);

        bytes memory bytecode = I_DEPLOYER.parse2("a b:, _: add(a b);");
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(Float.unwrap(fa));
        inputs[1] = StackItem.wrap(Float.unwrap(fb));
        (StackItem[] memory stack,) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: LibNamespace.qualifyNamespace(StateNamespace.wrap(0), address(this)),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: new bytes32[][](0),
                inputs: inputs,
                stateOverlay: new bytes32[](0)
            })
        );
        // 2 inputs + 1 op output = 3 stack items.
        assertEq(stack.length, 3);
        // Top of stack is the add result.
        Float expected = fa.add(fb);
        assertTrue(Float.wrap(StackItem.unwrap(stack[0])).eq(expected));
    }
}
