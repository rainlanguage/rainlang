// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {BytecodeTest} from "test/abstract/BytecodeTest.sol";
import {LibBytecode, SourceIndexOutOfBounds} from "../../../../src/lib/bytecode/LibBytecode.sol";
import {LibBytecodeSlow} from "test/src/lib/bytecode/LibBytecodeSlow.sol";

contract LibBytecodeSourceStackAllocationTest is BytecodeTest {
    /// Concrete value-pinning tests for sourceStackAllocation.
    function testSourceStackAllocationConcrete() external pure {
        // 1 source, 0 ops, allocation=0, inputs=0, outputs=0.
        assertEq(LibBytecode.sourceStackAllocation(hex"01000000000000", 0), 0);
        // 1 source, 0 ops, allocation=5, inputs=0, outputs=0.
        assertEq(LibBytecode.sourceStackAllocation(hex"01000000050000", 0), 5);
        // 1 source, 0 ops, allocation=0xFF, inputs=0, outputs=0.
        assertEq(LibBytecode.sourceStackAllocation(hex"01000000ff0000", 0), 0xFF);
        // 1 source, 2 ops, allocation=10, inputs=2, outputs=5.
        assertEq(LibBytecode.sourceStackAllocation(hex"010000020a02050000000000000000", 0), 10);
        // 2 sources: source 0 alloc=3, source 1 alloc=7.
        assertEq(LibBytecode.sourceStackAllocation(hex"02000000040003000000070000", 0), 3);
        assertEq(LibBytecode.sourceStackAllocation(hex"02000000040003000000070000", 1), 7);
    }

    function sourceStackAllocationExternal(bytes memory bytecode, uint256 sourceIndex)
        external
        pure
        returns (uint256 allocation)
    {
        return LibBytecode.sourceStackAllocation(bytecode, sourceIndex);
    }

    /// Getting the source stack allocation for an index beyond the sources
    /// should fail.
    function testSourceStackAllocationIndexOutOfBounds(
        bytes memory bytecode,
        uint256 sourceCount,
        uint256 sourceIndex,
        bytes32 seed
    ) external {
        conformBytecode(bytecode, sourceCount, seed);
        sourceCount = LibBytecode.sourceCount(bytecode);
        sourceIndex = bound(sourceIndex, sourceCount, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(SourceIndexOutOfBounds.selector, sourceIndex, bytecode));
        this.sourceStackAllocationExternal(bytecode, sourceIndex);
    }

    /// Test against a reference implementation.
    function testSourceStackAllocationAgainstSlow(
        bytes memory bytecode,
        uint256 sourceCount,
        uint256 sourceIndex,
        bytes32 seed
    ) external pure {
        conformBytecode(bytecode, sourceCount, seed);
        sourceCount = LibBytecode.sourceCount(bytecode);
        vm.assume(sourceCount > 0);
        sourceIndex = bound(sourceIndex, 0, sourceCount - 1);
        assertEq(
            LibBytecode.sourceStackAllocation(bytecode, sourceIndex),
            LibBytecodeSlow.sourceStackAllocationSlow(bytecode, sourceIndex)
        );
    }
}
