// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {LibInterpreterState, InterpreterState} from "../../../../src/lib/state/LibInterpreterState.sol";
import {LibAllStandardOps} from "../../../../src/lib/op/LibAllStandardOps.sol";
import {LibEval} from "../../../../src/lib/eval/LibEval.sol";
import {MemoryKV} from "rain.lib.memkv/lib/LibMemoryKV.sol";
import {
    IInterpreterStoreV3,
    FullyQualifiedNamespace
} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

contract LibEvalFBoundsTest is Test {
    /// Due to the mod of indexes to function pointers the indexes wrap at the
    /// length of the function pointers. Test that the length of the fn pointers
    /// + 1 is the constant op.
    function testEvalFBoundsModConstant(bytes32 c) public view {
        bytes memory fs = LibAllStandardOps.opcodeFunctionPointers();

        bytes memory bytecode =
        // 1 source
         hex"01"
            // 0 offset
            hex"0000"
            // 37 op
            hex"25"
            // 37 stack allocation
            hex"25"
            // 0 input
            hex"00"
            // 37 output
            hex"25"
            // 0: constant 0
            hex"01000000"
            // 1: constant 0
            hex"01000000"
            // 2: constant 0
            hex"01000000"
            // 3: constant 0
            hex"01000000"
            // 4: constant 0
            hex"01000000"
            // 5: constant 0
            hex"01000000"
            // 6: constant 0
            hex"01000000"
            // 7: constant 0
            hex"01000000"
            // 8: constant 0
            hex"01000000"
            // 9: constant 0
            hex"01000000"
            // 10: constant 0
            hex"01000000"
            // 11: constant 0
            hex"01000000"
            // 12: constant 0
            hex"01000000"
            // 13: constant 0
            hex"01000000"
            // 14: constant 0
            hex"01000000"
            // 15: constant 0
            hex"01000000"
            // 16: constant 0
            hex"01000000"
            // 17: constant 0
            hex"01000000"
            // 18: constant 0
            hex"01000000"
            // 19: constant 0
            hex"01000000"
            // 20: constant 0
            hex"01000000"
            // 21: constant 0
            hex"01000000"
            // 22: constant 0
            hex"01000000"
            // 23: constant 0
            hex"01000000"
            // 24: constant 0
            hex"01000000"
            // 25: constant 0
            hex"01000000"
            // 26: constant 0
            hex"01000000"
            // 27: constant 0
            hex"01000000"
            // 28: constant 0
            hex"01000000"
            // 29: constant 0
            hex"01000000"
            // 30: constant 0
            hex"01000000"
            // 31: constant 0
            hex"01000000"
            // 32: constant 0
            hex"01000000"
            // 33: constant 0
            hex"01000000"
            // 34: constant 0
            hex"01000000"
            // 35: constant 0
            hex"01000000"
            // 36: constant 0
            hex"01000000";

        uint256 expectedLength = 37;

        StackItem[][] memory stacks = new StackItem[][](1);
        stacks[0] = new StackItem[](expectedLength);
        bytes32[] memory constants = new bytes32[](1);
        constants[0] = c;
        bytes32[][] memory context = new bytes32[][](0);
        InterpreterState memory state = InterpreterState(
            LibInterpreterState.stackBottoms(stacks),
            constants,
            0,
            MemoryKV.wrap(0),
            FullyQualifiedNamespace.wrap(0),
            IInterpreterStoreV3(address(0)),
            context,
            bytecode,
            fs
        );

        (StackItem[] memory outputs, bytes32[] memory kvs) = LibEval.eval4(state, new StackItem[](0), type(uint256).max);
        assertEq(outputs.length, expectedLength);
        for (uint256 i = 0; i < outputs.length; i++) {
            assertEq(StackItem.unwrap(outputs[i]), c);
        }
        assertEq(kvs.length, 0);

        // Replace the constant byte with constant from the next octave.
        for (uint256 i = 7; i < bytecode.length; i += 4) {
            bytecode[i] = bytes1(uint8(uint8(fs.length / 2) + 1));
        }

        (outputs, kvs) = LibEval.eval4(state, new StackItem[](0), type(uint256).max);
        assertEq(outputs.length, expectedLength);
        for (uint256 i = 0; i < outputs.length; i++) {
            assertEq(StackItem.unwrap(outputs[i]), c);
        }
        assertEq(kvs.length, 0);
    }
}
