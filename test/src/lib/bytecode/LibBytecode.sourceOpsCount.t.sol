// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {BytecodeTest} from "test/abstract/BytecodeTest.sol";
import {LibBytecode, SourceIndexOutOfBounds} from "../../../../src/lib/bytecode/LibBytecode.sol";
import {LibBytecodeSlow} from "test/src/lib/bytecode/LibBytecodeSlow.sol";

contract LibBytecodeSourceOpsCountTest is BytecodeTest {
    function sourceOpsCountExternal(bytes memory bytecode, uint256 sourceIndex) external pure returns (uint256 count) {
        return LibBytecode.sourceOpsCount(bytecode, sourceIndex);
    }

    function testSourceOpsCount() external pure {
        // 1 source 0 offset 0 header
        assertEq(LibBytecode.sourceOpsCount(hex"01000000000000", 0), 0);
        // 1 source 0 offset some header (should be 1)
        assertEq(LibBytecode.sourceOpsCount(hex"01000001020304", 0), 1);
        // 1 source 2 offset some header
        assertEq(LibBytecode.sourceOpsCount(hex"010002ffff01020304", 0), 1);
        // 2 source 8 offset some header index 1
        assertEq(LibBytecode.sourceOpsCount(hex"020000000801000000ffffffff01020304ffffffff", 1), 1);
    }

    /// Getting the source ops count for an index beyond the sources should fail.
    function testSourceOpsCountIndexOutOfBounds(
        bytes memory bytecode,
        uint256 sourceCount,
        uint256 sourceIndex,
        bytes32 seed
    ) external {
        conformBytecode(bytecode, sourceCount, seed);
        sourceCount = LibBytecode.sourceCount(bytecode);
        sourceIndex = bound(sourceIndex, sourceCount, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(SourceIndexOutOfBounds.selector, sourceIndex, bytecode));
        this.sourceOpsCountExternal(bytecode, sourceIndex);
    }

    /// Test against a reference implementation.
    function testSourceOpsCountAgainstSlow(
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
            LibBytecode.sourceOpsCount(bytecode, sourceIndex), LibBytecodeSlow.sourceOpsCountSlow(bytecode, sourceIndex)
        );
    }
}
