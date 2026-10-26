// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {BytecodeTest} from "test/abstract/BytecodeTest.sol";
import {LibBytecode, SourceIndexOutOfBounds} from "../../../../src/lib/bytecode/LibBytecode.sol";
import {LibBytecodeSlow} from "test/src/lib/bytecode/LibBytecodeSlow.sol";
import {Pointer} from "rain-solmem-0.1.28/src/lib/LibPointer.sol";

contract LibBytecodeSourcePointerTest is BytecodeTest {
    function sourcePointerExternal(bytes memory bytecode, uint256 sourceIndex) external pure returns (Pointer pointer) {
        return LibBytecode.sourcePointer(bytecode, sourceIndex);
    }

    /// Getting the source pointer for an empty bytecode should fail. Tests empty
    /// bytes.
    function testSourcePointerEmpty0(uint256 sourceIndex) external {
        bytes memory bytecode = hex"";
        vm.expectRevert(abi.encodeWithSelector(SourceIndexOutOfBounds.selector, sourceIndex, bytecode));
        this.sourcePointerExternal(bytecode, sourceIndex);
    }

    /// Getting the source pointer for an empty bytecode should fail. Tests
    /// non-empty bytes but with no source.
    function testSourcePointerEmpty1(uint256 sourceIndex) external {
        bytes memory bytecode = hex"00";
        vm.expectRevert(abi.encodeWithSelector(SourceIndexOutOfBounds.selector, sourceIndex, bytecode));
        this.sourcePointerExternal(bytecode, sourceIndex);
    }

    /// Getting a source pointer for an index beyond the sources should fail.
    function testSourcePointerIndexOutOfBounds(
        bytes memory bytecode,
        uint256 sourceCount,
        uint256 sourceIndex,
        bytes32 seed
    ) external {
        conformBytecode(bytecode, sourceCount, seed);
        sourceCount = LibBytecode.sourceCount(bytecode);
        sourceIndex = bound(sourceIndex, sourceCount, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(SourceIndexOutOfBounds.selector, sourceIndex, bytecode));
        this.sourcePointerExternal(bytecode, sourceIndex);
    }

    /// Test against a reference implementation.
    function testSourcePointerAgainstSlow(bytes memory bytecode, uint256 sourceCount, uint256 sourceIndex, bytes32 seed)
        external
        pure
    {
        conformBytecode(bytecode, sourceCount, seed);
        sourceCount = LibBytecode.sourceCount(bytecode);
        vm.assume(sourceCount > 0);
        sourceIndex = bound(sourceIndex, 0, sourceCount - 1);
        assertEq(
            Pointer.unwrap(LibBytecode.sourcePointer(bytecode, sourceIndex)),
            Pointer.unwrap(LibBytecodeSlow.sourcePointerSlow(bytecode, sourceIndex))
        );
    }
}
