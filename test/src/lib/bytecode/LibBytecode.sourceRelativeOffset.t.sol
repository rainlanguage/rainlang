// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {BytecodeTest} from "test/abstract/BytecodeTest.sol";
import {LibBytecode, SourceIndexOutOfBounds} from "../../../../src/lib/bytecode/LibBytecode.sol";
import {LibBytecodeSlow} from "test/src/lib/bytecode/LibBytecodeSlow.sol";

contract LibBytecodeSourceRelativeOffsetTest is BytecodeTest {
    /// Test some examples of source relative offsets.
    function testSourceRelativeOffsetHappy() external pure {
        // 1 source 0 offset 0 header
        assertEq(LibBytecode.sourceRelativeOffset(hex"01000000000000", 0), 0);
        // 1 source 0 offset some header
        assertEq(LibBytecode.sourceRelativeOffset(hex"01000001020304", 0), 0);
        // 1 source 2 offset some header
        assertEq(LibBytecode.sourceRelativeOffset(hex"010002ffff01020304", 0), 2);
        // 2 source 8 offset some header index 1
        assertEq(LibBytecode.sourceRelativeOffset(hex"0200000008ffffffff01020304ffffffff", 1), 8);
    }

    function sourceRelativeOffsetExternal(bytes memory bytecode, uint256 sourceIndex)
        external
        pure
        returns (uint256 offset)
    {
        return LibBytecode.sourceRelativeOffset(bytecode, sourceIndex);
    }

    function checkSourceRelativeOffsetIndexOutOfBounds(bytes memory bytecode, uint256 sourceIndex) internal {
        vm.expectRevert(abi.encodeWithSelector(SourceIndexOutOfBounds.selector, sourceIndex, bytecode));
        this.sourceRelativeOffsetExternal(bytecode, sourceIndex);
    }

    /// Test some examples of source relative offset errors.
    function testSourceRelativeOffsetIndexError() external {
        // 0 source 0 offset 0 header
        // index 0
        checkSourceRelativeOffsetIndexOutOfBounds("", 0);
        checkSourceRelativeOffsetIndexOutOfBounds(hex"00", 0);
        checkSourceRelativeOffsetIndexOutOfBounds(hex"0000", 0);
        checkSourceRelativeOffsetIndexOutOfBounds(hex"000000", 0);
        // index 1
        checkSourceRelativeOffsetIndexOutOfBounds(hex"", 1);
        checkSourceRelativeOffsetIndexOutOfBounds(hex"00", 1);
        checkSourceRelativeOffsetIndexOutOfBounds(hex"0000", 1);
        checkSourceRelativeOffsetIndexOutOfBounds(hex"000000", 1);
        // index 2
        checkSourceRelativeOffsetIndexOutOfBounds(hex"", 2);
        checkSourceRelativeOffsetIndexOutOfBounds(hex"00", 2);
        checkSourceRelativeOffsetIndexOutOfBounds(hex"0000", 2);
        checkSourceRelativeOffsetIndexOutOfBounds(hex"000000", 2);

        // 1 source 0 offset 0 header
        // index 1
        checkSourceRelativeOffsetIndexOutOfBounds(hex"01", 1);
        checkSourceRelativeOffsetIndexOutOfBounds(hex"0100", 1);
        // has offset but not header
        checkSourceRelativeOffsetIndexOutOfBounds(hex"010000", 1);
        // with header
        checkSourceRelativeOffsetIndexOutOfBounds(hex"01000000000000", 1);
    }

    /// Test against a reference implementation.
    function testSourceRelativeOffsetReference(
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
            LibBytecode.sourceRelativeOffset(bytecode, sourceIndex),
            LibBytecodeSlow.sourceRelativeOffsetSlow(bytecode, sourceIndex)
        );
    }

    /// The relative offset is a 16 bit big-endian value. These cases pin
    /// offsets that do not fit in a single byte (>= 0x100). A mask that
    /// dropped the high byte would read a different, smaller offset. `sourceRelativeOffset` does not validate that the offset
    /// points anywhere real (that is `checkNoOOBPointers`' job), so the offset
    /// bytes can be set directly without a conforming body.
    function testSourceRelativeOffsetHighByte() external pure {
        // count = 2, source 0 offset 0x0000, source 1 offset 0x0102 (258).
        assertEq(LibBytecode.sourceRelativeOffset(hex"0200000102", 1), 0x0102);
        // count = 1, source 0 offset 0xFF00 (65280): the value lives entirely
        // in the high byte, so dropping it would read 0.
        assertEq(LibBytecode.sourceRelativeOffset(hex"01FF00", 0), 0xFF00);
        // count = 1, source 0 offset 0xFFFF (65535): full 16 bits set.
        assertEq(LibBytecode.sourceRelativeOffset(hex"01FFFF", 0), 0xFFFF);
    }

    /// Reference cross-check for high (>= 0x100) offsets. The slow
    /// implementation independently reads both offset bytes, so it diverges
    /// from any production read that drops the high byte.
    function testSourceRelativeOffsetHighByteReference(uint16 offset) external pure {
        vm.assume(offset >= 0x100);
        // count = 1, single offset taken from the fuzzed high value.
        bytes memory bytecode = new bytes(3);
        bytecode[0] = bytes1(uint8(1));
        // offset is uint16 so its high byte always fits in uint8.
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[1] = bytes1(uint8(offset >> 8));
        // Writing the low byte of a 16 bit offset, so truncating is the intent.
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[2] = bytes1(uint8(offset));
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, 0), offset);
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, 0), LibBytecodeSlow.sourceRelativeOffsetSlow(bytecode, 0));
    }
}
