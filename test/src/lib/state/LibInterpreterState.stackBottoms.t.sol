// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibInterpreterState} from "../../../../src/lib/state/LibInterpreterState.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

/// @title LibInterpreterStateStackBottomsTest
/// @notice Tests for stackBottoms(), which converts pre-allocated stack arrays
/// into bottom pointers. Each bottom pointer is the address just past the last
/// element: `array + 0x20 * (length + 1)`.
contract LibInterpreterStateStackBottomsTest is Test {
    /// An empty stacks array must produce an empty bottoms array.
    function testStackBottomsEmpty() external pure {
        StackItem[][] memory stacks = new StackItem[][](0);
        Pointer[] memory bottoms = LibInterpreterState.stackBottoms(stacks);
        assertEq(bottoms.length, 0);
    }

    /// A single stack's bottom pointer must equal the array address plus
    /// 0x20 * (length + 1), i.e. just past the last element.
    function testStackBottomsSingle(uint8 len) external pure {
        StackItem[] memory stack = new StackItem[](len);
        StackItem[][] memory stacks = new StackItem[][](1);
        stacks[0] = stack;

        Pointer[] memory bottoms = LibInterpreterState.stackBottoms(stacks);
        assertEq(bottoms.length, 1);

        uint256 stackAddr;
        assembly ("memory-safe") {
            stackAddr := stack
        }
        uint256 expectedBottom = stackAddr + 0x20 * (uint256(len) + 1);
        assertEq(Pointer.unwrap(bottoms[0]), expectedBottom);
    }

    /// Multiple stacks of different sizes must each produce a correct bottom
    /// pointer independently.
    function testStackBottomsMultiple(uint8 lenA, uint8 lenB, uint8 lenC) external pure {
        StackItem[] memory a = new StackItem[](lenA);
        StackItem[] memory b = new StackItem[](lenB);
        StackItem[] memory c = new StackItem[](lenC);
        StackItem[][] memory stacks = new StackItem[][](3);
        stacks[0] = a;
        stacks[1] = b;
        stacks[2] = c;

        Pointer[] memory bottoms = LibInterpreterState.stackBottoms(stacks);
        assertEq(bottoms.length, 3);

        uint256 addrA;
        uint256 addrB;
        uint256 addrC;
        assembly ("memory-safe") {
            addrA := a
            addrB := b
            addrC := c
        }
        assertEq(Pointer.unwrap(bottoms[0]), addrA + 0x20 * (uint256(lenA) + 1));
        assertEq(Pointer.unwrap(bottoms[1]), addrB + 0x20 * (uint256(lenB) + 1));
        assertEq(Pointer.unwrap(bottoms[2]), addrC + 0x20 * (uint256(lenC) + 1));
    }
}
