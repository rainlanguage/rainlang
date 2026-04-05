// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    RainlangExpressionDeployerDeploymentTest
} from "test/abstract/RainlangExpressionDeployerDeploymentTest.sol";
import {StateNamespace} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";
import {EvalV4, SourceIndexV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibNamespace} from "rain.interpreter.interface/lib/ns/LibNamespace.sol";

/// evalLoop processes opcodes in batches of 8 via an unrolled loop that reads
/// one 32-byte word (8 x 4-byte opcodes) per iteration. Leftover opcodes
/// (count mod 8) are handled by a separate remainder loop. These tests
/// exercise opcode-count edge cases: zero opcodes (neither loop body runs),
/// and exact multiples of 8 (remainder is zero, only the unrolled loop runs).
contract LibEvalOpcodeCountEdgeCasesTest is RainlangExpressionDeployerDeploymentTest {
    /// Evaluating a zero-opcode source (no inputs, no ops) must succeed
    /// and return no outputs.
    function testEvalZeroOpcodeSource() external view {
        bytes memory bytecode = I_DEPLOYER.parse2(":;");
        (StackItem[] memory stack,) = I_INTERPRETER.eval4(
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
        assertEq(stack.length, 0);
    }

    /// Zero-opcode source with inputs — inputs appear as outputs with no
    /// ops executed.
    function testEvalZeroOpcodeSourceWithInputs(uint256 a, uint256 b) external view {
        bytes memory bytecode = I_DEPLOYER.parse2("x y:;");
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(a));
        inputs[1] = StackItem.wrap(bytes32(b));
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
        assertEq(stack.length, 2);
        assertEq(StackItem.unwrap(stack[0]), bytes32(a));
        assertEq(StackItem.unwrap(stack[1]), bytes32(b));
    }

    /// Exactly 8 opcodes — one full unrolled-loop iteration, zero remainder.
    /// Each opcode is a distinct hex literal so we can verify every value
    /// was executed in the correct order.
    function testEvalExactly8Opcodes() external view {
        bytes memory bytecode =
            I_DEPLOYER.parse2("_: 0x01," "_: 0x02," "_: 0x03," "_: 0x04," "_: 0x05," "_: 0x06," "_: 0x07," "_: 0x08;");
        (StackItem[] memory stack,) = I_INTERPRETER.eval4(
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
        assertEq(stack.length, 8);
        // stack[0] is top of stack (last pushed).
        assertEq(StackItem.unwrap(stack[0]), bytes32(uint256(8)));
        assertEq(StackItem.unwrap(stack[1]), bytes32(uint256(7)));
        assertEq(StackItem.unwrap(stack[2]), bytes32(uint256(6)));
        assertEq(StackItem.unwrap(stack[3]), bytes32(uint256(5)));
        assertEq(StackItem.unwrap(stack[4]), bytes32(uint256(4)));
        assertEq(StackItem.unwrap(stack[5]), bytes32(uint256(3)));
        assertEq(StackItem.unwrap(stack[6]), bytes32(uint256(2)));
        assertEq(StackItem.unwrap(stack[7]), bytes32(uint256(1)));
    }

    /// Exactly 16 opcodes — two full unrolled-loop iterations, zero remainder.
    /// Exercises the loop-continuation path (cursor advances by 0x20 and
    /// re-enters) while still having zero remainder.
    function testEvalExactly16Opcodes() external view {
        bytes memory bytecode = I_DEPLOYER.parse2(
            "_: 0x01," "_: 0x02," "_: 0x03," "_: 0x04," "_: 0x05," "_: 0x06," "_: 0x07," "_: 0x08," "_: 0x09,"
            "_: 0x0a," "_: 0x0b," "_: 0x0c," "_: 0x0d," "_: 0x0e," "_: 0x0f," "_: 0x10;"
        );
        (StackItem[] memory stack,) = I_INTERPRETER.eval4(
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
        assertEq(stack.length, 16);
        // stack[0] is top of stack (last pushed).
        for (uint256 i = 0; i < 16; i++) {
            assertEq(StackItem.unwrap(stack[i]), bytes32(uint256(16 - i)));
        }
    }
}
