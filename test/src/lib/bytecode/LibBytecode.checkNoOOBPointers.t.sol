// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {BytecodeTest} from "test/abstract/BytecodeTest.sol";
import {
    LibBytecode,
    UnexpectedSources,
    TruncatedHeaderOffsets,
    TruncatedHeader,
    UnexpectedTrailingOffsetBytes,
    TruncatedSource,
    StackSizingsNotMonotonic
} from "../../../../src/lib/bytecode/LibBytecode.sol";

contract LibBytecodeCheckNoOOBPointersTest is BytecodeTest {
    /// Test that all conforming bytecodes pass.
    function testCheckNoOOBPointersConforming(bytes memory bytecode, uint256 sourceCount, bytes32 seed) external pure {
        conformBytecode(bytecode, sourceCount, seed);
        LibBytecode.checkNoOOBPointers(bytecode);
    }

    /// A single source cannot hold more than 0xFF ops, as the ops count is one
    /// header byte, so conforming a long bytecode to one source truncates it
    /// to a full source that passes.
    function testCheckNoOOBPointersConformingOpsCountMax() external pure {
        bytes memory bytecode = new bytes(3648);
        conformBytecode(bytecode, 1, bytes32(uint256(0x554)));
        LibBytecode.checkNoOOBPointers(bytecode);
        assertEq(LibBytecode.sourceCount(bytecode), uint256(1));
        assertEq(LibBytecode.sourceOpsCount(bytecode, 0), uint256(0xFF));
        assertEq(bytecode.length, uint256(1 + 2 + 4 + 0xFF * 4));
    }

    /// Every source offset is two bytes, so conforming a bytecode longer than
    /// those offsets can address truncates it to one that passes.
    function testCheckNoOOBPointersConformingOffsetMax() external pure {
        bytes memory bytecode = new bytes(0x20000);
        conformBytecode(bytecode, 0xFF, bytes32(0));
        LibBytecode.checkNoOOBPointers(bytecode);
        uint256 sourceCount = LibBytecode.sourceCount(bytecode);
        uint256 opsCount = 0;
        for (uint256 i = 0; i < sourceCount; i++) {
            opsCount += LibBytecode.sourceOpsCount(bytecode, i);
        }
        // The source count leaves room for more ops than the offsets can
        // address, so the offsets are what truncate.
        assertTrue(sourceCount * 0xFF > (0xFFFF - sourceCount * 4) / 4);
        assertEq(opsCount, (0xFFFF - sourceCount * 4) / 4);
        assertEq(bytecode.length, 1 + sourceCount * 2 + sourceCount * 4 + opsCount * 4);
    }

    /// Expose the library function externally so we can expect reverts against
    /// it.
    //forge-lint: disable-next-line(mixed-case-function)
    function checkNoOOBPointersExternal(bytes memory bytecode) external pure {
        LibBytecode.checkNoOOBPointers(bytecode);
    }

    /// Test that a zero length bytecode passes.
    function testCheckNoOOBPointers0() external pure {
        LibBytecode.checkNoOOBPointers("");
    }

    /// Test that a zero count bytecode length 1 passes.
    function testCheckNoOOBPointers1() external pure {
        LibBytecode.checkNoOOBPointers(hex"00");
    }

    /// Test that a zero count bytecode length > 1 fails as `UnexpectedSources`.
    function testCheckNoOOBPointers1Fail(bytes memory bytecode) external {
        vm.assume(bytecode.length > 1);
        bytecode[0] = 0;

        vm.expectRevert(abi.encodeWithSelector(UnexpectedSources.selector, bytecode));
        this.checkNoOOBPointersExternal(bytecode);
    }

    /// If the relative offsets are truncated the bytecode fails as
    /// `TruncatedHeaderOffsets`.
    function testCheckNoOOBPointersOffsetsTruncated(bytes memory bytecode, uint8 sourceCount, uint256 length) external {
        vm.assume(sourceCount > 0);
        vm.assume(bytecode.length > 0);
        bytecode[0] = bytes1(sourceCount);

        // Length anywhere from 1 to preserve the count up to 1 less than the
        // offsets allocation should throw.
        length = bound(length, 1, uint256(sourceCount) * 2);

        // Truncate the bytecode to the length if needed.
        if (bytecode.length > length) {
            assembly ("memory-safe") {
                mstore(bytecode, length)
            }
        }

        vm.expectRevert(abi.encodeWithSelector(TruncatedHeaderOffsets.selector, bytecode));
        this.checkNoOOBPointersExternal(bytecode);
    }

    /// If any of the relative offsets point to a space that doesn't fit a header
    /// the bytecode fails as `TruncatedHeader`.
    function testCheckNoOOBPointersHeaderTruncated(
        bytes memory bytecode,
        uint8 sourceCount,
        bytes32 seed,
        uint256 corruptOffset
    ) external {
        conformBytecode(bytecode, sourceCount, seed);
        // The case of empty sources is not relevant.
        vm.assume(bytecode.length > 1);
        sourceCount = uint8(bytecode[0]);

        // Randomly corrupt an offset pointer.
        uint256 sourceRelativeStart = 1 + uint256(sourceCount) * 2;
        seed = keccak256(abi.encodePacked(seed, uint256(0)));
        uint256 offsetIndex = uint256(seed) % sourceCount;
        uint256 nextOffset;
        if (offsetIndex == sourceCount - 1) {
            nextOffset = bytecode.length - sourceRelativeStart;
        } else {
            uint256 nextOffsetPosition = (offsetIndex + 1) * 2 + 1;
            nextOffset =
                (uint256(uint8(bytecode[nextOffsetPosition])) << 8) | uint256(uint8(bytecode[nextOffsetPosition + 1]));
        }
        corruptOffset = bound(corruptOffset, nextOffset - 3, type(uint16).max);
        uint256 offsetPosition = offsetIndex * 2 + 1;
        // Taking the corrupt offset one byte at a time, so a shift and truncate
        // is expected.
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[offsetPosition] = bytes1(uint8(corruptOffset >> 8));
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[offsetPosition + 1] = bytes1(uint8(corruptOffset));

        vm.expectRevert(abi.encodeWithSelector(TruncatedHeader.selector, bytecode));
        this.checkNoOOBPointersExternal(bytecode);
    }

    /// Any corruption of the ops count for a given source header fails as
    /// `TruncatedSource`.
    function testCheckNoOOBPointersSourceTruncated(
        bytes memory bytecode,
        uint8 sourceCount,
        bytes32 seed,
        uint8 corruptOpCount
    ) external {
        conformBytecode(bytecode, sourceCount, seed);
        // The case of empty sources is not relevant.
        vm.assume(bytecode.length > 1);
        sourceCount = uint8(bytecode[0]);

        // Randomly corrupt an ops count.
        uint256 sourceRelativeStart = 1 + uint256(sourceCount) * 2;
        seed = keccak256(abi.encodePacked(seed, uint256(0)));
        uint256 offsetIndex = uint256(seed) % sourceCount;
        uint256 offsetPosition = offsetIndex * 2 + 1;
        uint256 offset = (uint256(uint8(bytecode[offsetPosition])) << 8) | uint256(uint8(bytecode[offsetPosition + 1]));
        uint256 opsCount = uint256(uint8(bytecode[sourceRelativeStart + offset]));
        vm.assume(opsCount != uint8(corruptOpCount));
        bytecode[sourceRelativeStart + offset] = bytes1(corruptOpCount);

        vm.expectRevert(abi.encodeWithSelector(TruncatedSource.selector, bytecode));
        this.checkNoOOBPointersExternal(bytecode);
    }

    /// If the initial offset is anything other than 0 the bytecode fails as
    /// `UnexpectedTrailingOffsetBytes`.
    function testCheckNoOOBPointersTrailingOffsetBytes(
        bytes memory bytecode,
        bytes memory garbage,
        uint8 sourceCount,
        bytes32 seed
    ) external {
        vm.assume(garbage.length > 0);
        conformBytecode(bytecode, sourceCount, seed);
        // The case of empty sources is not relevant.
        vm.assume(bytecode.length > 1);
        sourceCount = uint8(bytecode[0]);

        // Split the bytecode into two parts at the end of the offset pointers.
        uint256 sourceRelativeStart = 1 + uint256(sourceCount) * 2;

        // Shifted offsets must still fit their two bytes.
        {
            uint256 lastOffsetPosition = (uint256(sourceCount) - 1) * 2 + 1;
            uint256 lastOffset =
                (uint256(uint8(bytecode[lastOffsetPosition])) << 8) | uint256(uint8(bytecode[lastOffsetPosition + 1]));
            uint256 maxGarbageLength = type(uint16).max - lastOffset;
            if (garbage.length > maxGarbageLength) {
                assembly ("memory-safe") {
                    mstore(garbage, maxGarbageLength)
                }
            }
        }

        uint256 sourceAbsoluteStart;
        assembly ("memory-safe") {
            sourceAbsoluteStart := add(bytecode, add(0x20, sourceRelativeStart))
        }

        uint256 originalLength = bytecode.length;

        // Truncate the bytecode down to the source relative start.
        assembly ("memory-safe") {
            mstore(bytecode, sourceRelativeStart)
        }

        bytes memory bytecodeCorrupted = abi.encodePacked(bytecode, garbage);

        // Need to add the garbage length to every offset.
        for (uint256 i = 0; i < sourceCount; i++) {
            uint256 offsetPosition = i * 2 + 1;
            uint256 offset = (uint256(uint8(bytecodeCorrupted[offsetPosition])) << 8)
                | uint256(uint8(bytecodeCorrupted[offsetPosition + 1]));
            offset += garbage.length;
            // Deliberately writing offset as two bytes so the truncation per
            // byte is intentional.
            //forge-lint: disable-next-line(unsafe-typecast)
            bytecodeCorrupted[offsetPosition] = bytes1(uint8(offset >> 8));
            //forge-lint: disable-next-line(unsafe-typecast)
            bytecodeCorrupted[offsetPosition + 1] = bytes1(uint8(offset));
        }

        // Restore the suffix of the bytecode.
        uint256 suffixLength = originalLength - sourceRelativeStart;
        assembly ("memory-safe") {
            bytecode := add(bytecode, sourceRelativeStart)
            mstore(bytecode, suffixLength)
        }
        bytecodeCorrupted = abi.encodePacked(bytecodeCorrupted, bytecode);

        vm.expectRevert(abi.encodeWithSelector(UnexpectedTrailingOffsetBytes.selector, bytecodeCorrupted));
        this.checkNoOOBPointersExternal(bytecodeCorrupted);
    }

    /// Randomly corrupting the sources count MUST error.
    function testCheckNoOOBPointersCorruptSourcesCount(
        bytes memory bytecode,
        uint8 sourceCount,
        bytes32 seed,
        uint8 corruptSourceCount
    ) external {
        conformBytecode(bytecode, sourceCount, seed);
        vm.assume(bytecode.length > 0);
        sourceCount = uint8(bytecode[0]);

        // Randomly corrupt the sources count.
        vm.assume(corruptSourceCount != sourceCount);
        bytecode[0] = bytes1(corruptSourceCount);

        // Any kind of error is fine. We have more specific tests to check each
        // error type.
        vm.expectRevert();
        this.checkNoOOBPointersExternal(bytecode);
    }

    /// Randomly corrupting any byte in the offset pointers MUST error.
    function testCheckNoOOBPointersCorruptOffsetPointer(
        bytes memory bytecode,
        uint8 sourceCount,
        bytes32 seed,
        uint8 corruptOffsetByte
    ) external {
        conformBytecode(bytecode, sourceCount, seed);
        vm.assume(bytecode.length > 0);
        sourceCount = uint8(bytecode[0]);
        vm.assume(sourceCount > 0);

        uint256 pointerRegionSize = uint256(sourceCount) * 2;
        uint256 corruptIndex = (uint256(seed) % pointerRegionSize) + 1;
        vm.assume(bytecode[corruptIndex] != bytes1(corruptOffsetByte));
        bytecode[corruptIndex] = bytes1(corruptOffsetByte);

        // Any kind of error is fine. We have more specific tests to check each
        // error type.
        vm.expectRevert();
        this.checkNoOOBPointersExternal(bytecode);
    }

    /// Randomly corrupting any ops count MUST error.
    function testCheckNoOOBPointersCorruptOpsCount(
        bytes memory bytecode,
        uint8 sourceCount,
        bytes32 seed,
        uint8 corruptOpsCount
    ) external {
        conformBytecode(bytecode, sourceCount, seed);
        vm.assume(bytecode.length > 0);
        sourceCount = uint8(bytecode[0]);
        vm.assume(sourceCount > 0);

        uint256 sourceRelativeStart = 1 + uint256(sourceCount) * 2;

        // Pick an offset pointer.
        seed = keccak256(abi.encodePacked(seed, uint256(0)));
        uint256 offsetIndex = uint256(seed) % sourceCount;
        uint256 offsetPosition = offsetIndex * 2 + 1;
        uint256 offset = (uint256(uint8(bytecode[offsetPosition])) << 8) | uint256(uint8(bytecode[offsetPosition + 1]));

        // Corrupt the ops count. This is the first byte of the header.
        uint256 headerPosition = sourceRelativeStart + offset;
        vm.assume(bytecode[headerPosition] != bytes1(corruptOpsCount));
        bytecode[headerPosition] = bytes1(corruptOpsCount);

        vm.expectRevert();
        this.checkNoOOBPointersExternal(bytecode);
    }

    /// Adding garbage to the end of the bytecode MUST error.
    function testCheckNoOOBPointersEndGarbage(bytes memory bytecode, bytes memory garbage) external {
        vm.assume(garbage.length > 0);
        conformBytecode(bytecode, 1, bytes32(0));
        vm.assume(bytecode.length > 0);
        bytecode = abi.encodePacked(bytecode, garbage);

        vm.expectRevert();
        this.checkNoOOBPointersExternal(bytecode);
    }

    /// If the inputs count is greater than the outputs count for some source
    /// the bytecode MUST error as `StackSizingsNotMonotonic`.
    function testCheckNoOOBPointersInputsNotMonotonic(
        bytes memory bytecode,
        uint8 sourceCount,
        bytes32 seed,
        uint256 corruptInputs,
        uint256 corruptOutputs
    ) external {
        conformBytecode(bytecode, sourceCount, seed);
        vm.assume(bytecode.length > 0);
        sourceCount = uint8(bytecode[0]);
        vm.assume(sourceCount > 0);

        uint256 sourceRelativeStart = 1 + uint256(sourceCount) * 2;

        // Pick an offset pointer.
        seed = keccak256(abi.encodePacked(seed, uint256(0)));
        uint256 offsetIndex = uint256(seed) % sourceCount;
        uint256 offsetPosition = offsetIndex * 2 + 1;
        uint256 offset = (uint256(uint8(bytecode[offsetPosition])) << 8) | uint256(uint8(bytecode[offsetPosition + 1]));

        {
            // Corrupt the inputs count. This is the third byte of the header.
            uint256 headerPosition = sourceRelativeStart + offset;
            uint256 inputsPosition = headerPosition + 2;
            uint256 outputsPosition = headerPosition + 3;

            uint256 inputs = uint256(uint8(bytecode[inputsPosition]));
            uint256 outputs = uint256(uint8(bytecode[outputsPosition]));
            if (outputs < type(uint8).max) {
                inputs = bound(corruptInputs, outputs + 1, type(uint8).max);
            } else {
                inputs = bound(corruptInputs, 1, type(uint8).max);
                outputs = bound(corruptOutputs, 0, inputs - 1);
            }
            // Inputs is either a single byte or bound so safe to cast like this.
            //forge-lint: disable-next-line(unsafe-typecast)
            bytecode[inputsPosition] = bytes1(uint8(inputs));
            // Outputs is a single byte or bound so safe to cast like this.
            //forge-lint: disable-next-line(unsafe-typecast)
            bytecode[outputsPosition] = bytes1(uint8(outputs));

            // Ensure the allocation is valid so we don't get false positives.
            uint256 allocation = uint256(uint8(bytecode[headerPosition + 1]));
            allocation = bound(allocation, outputs, type(uint8).max);
            // Allocation is bound so safe to cast.
            //forge-lint: disable-next-line(unsafe-typecast)
            bytecode[headerPosition + 1] = bytes1(uint8(allocation));
        }

        vm.expectRevert(abi.encodeWithSelector(StackSizingsNotMonotonic.selector, bytecode, offset));
        this.checkNoOOBPointersExternal(bytecode);
    }

    /// If the outputs count is greater than the allocation for some source
    /// the bytecode MUST error as `StackSizingsNotMonotonic`.
    function testCheckNoOOBPointersOutputsNotMonotonic(
        bytes memory bytecode,
        uint8 sourceCount,
        bytes32 seed,
        uint256 corruptOutputs,
        uint256 corruptAllocation
    ) external {
        conformBytecode(bytecode, sourceCount, seed);
        vm.assume(bytecode.length > 0);
        sourceCount = uint8(bytecode[0]);
        vm.assume(sourceCount > 0);

        uint256 sourceRelativeStart = 1 + uint256(sourceCount) * 2;

        // Pick an offset pointer.
        seed = keccak256(abi.encodePacked(seed, uint256(0)));
        uint256 offsetIndex = uint256(seed) % sourceCount;
        uint256 offsetPosition = offsetIndex * 2 + 1;
        uint256 offset = (uint256(uint8(bytecode[offsetPosition])) << 8) | uint256(uint8(bytecode[offsetPosition + 1]));

        {
            // Corrupt the outputs count. This is the fourth byte of the header.
            uint256 headerPosition = sourceRelativeStart + offset;
            uint256 allocationPosition = headerPosition + 1;
            uint256 outputsPosition = headerPosition + 3;

            uint256 outputs = uint256(uint8(bytecode[outputsPosition]));
            uint256 allocation = uint256(uint8(bytecode[allocationPosition]));
            if (allocation < type(uint8).max) {
                outputs = bound(corruptOutputs, allocation + 1, type(uint8).max);
            } else {
                outputs = bound(corruptOutputs, 1, type(uint8).max);
                allocation = bound(corruptAllocation, 0, outputs - 1);
            }
            // Outputs is either a single byte or bound above so it is safe to
            // cast like this.
            //forge-lint: disable-next-line(unsafe-typecast)
            bytecode[outputsPosition] = bytes1(uint8(outputs));
            // Allocation is either a single byte or bound above so it is safe
            // to cast like this.
            //forge-lint: disable-next-line(unsafe-typecast)
            bytecode[allocationPosition] = bytes1(uint8(allocation));

            // Ensure the inputs is valid so we don't get false positives.
            uint256 inputs = uint256(uint8(bytecode[headerPosition + 2]));
            inputs = bound(inputs, 0, outputs);
            // Outputs bound to type(uint8).max so this can't overflow due to
            // the inputs bound.
            //forge-lint: disable-next-line(unsafe-typecast)
            bytecode[headerPosition + 2] = bytes1(uint8(inputs));
        }

        vm.expectRevert(abi.encodeWithSelector(StackSizingsNotMonotonic.selector, bytecode, offset));
        this.checkNoOOBPointersExternal(bytecode);
    }

    /// Boundary: when the bytecode length is exactly `1 + sourceCount * 2`, the
    /// offset pointer table fills the bytecode with zero room for any source
    /// header. The offset-table bounds check `sourcesRelativeStart >
    /// bytecode.length` is `false` at this exact length (it only fires when the
    /// offsets themselves are truncated), so execution proceeds and the missing
    /// 4 byte header is caught downstream as `TruncatedHeader` rather than
    /// `TruncatedHeaderOffsets`. This pins the `>` boundary: a `>=` guard would
    /// short-circuit here and revert with `TruncatedHeaderOffsets` instead.
    function testCheckNoOOBPointersOffsetsExactNoHeaderRoomCount1() external {
        // count = 1, sourcesRelativeStart = 1 + 1 * 2 = 3, length = 3.
        // [01][offset_hi=00][offset_lo=00]
        bytes memory bytecode = hex"010000";
        vm.expectRevert(abi.encodeWithSelector(TruncatedHeader.selector, bytecode));
        this.checkNoOOBPointersExternal(bytecode);
    }

    /// As above with count = 2: sourcesRelativeStart = 1 + 2 * 2 = 5, length 5.
    /// [02][off0_hi=00][off0_lo=00][off1_hi=00][off1_lo=00]
    function testCheckNoOOBPointersOffsetsExactNoHeaderRoomCount2() external {
        bytes memory bytecode = hex"0200000000";
        vm.expectRevert(abi.encodeWithSelector(TruncatedHeader.selector, bytecode));
        this.checkNoOOBPointersExternal(bytecode);
    }

    /// Fuzz the boundary across all valid source counts. A bytecode that is
    /// exactly the count byte plus `count * 2` zeroed offset bytes (and nothing
    /// else) MUST revert with `TruncatedHeader`, never `TruncatedHeaderOffsets`.
    function testCheckNoOOBPointersOffsetsExactNoHeaderRoomFuzz(uint8 sourceCount) external {
        sourceCount = uint8(bound(sourceCount, 1, type(uint8).max));
        // 1 count byte + 2 bytes per source offset, no source headers.
        bytes memory bytecode = new bytes(1 + uint256(sourceCount) * 2);
        bytecode[0] = bytes1(sourceCount);
        // All offset bytes remain zero, which is well-formed for the offset
        // table (the first offset must be zero) but leaves no header room.
        vm.expectRevert(abi.encodeWithSelector(TruncatedHeader.selector, bytecode));
        this.checkNoOOBPointersExternal(bytecode);
    }

    /// The `TruncatedHeader` counterexample decoded on rainlang issue 614: 14 sources,
    /// source 13 holds the only op, offset 5 is corrupted to 21933.
    function testCheckNoOOBPointersHeaderTruncatedDecodedCounterexample() external {
        bytes memory bytecode = new bytes(89);
        bytecode[0] = bytes1(uint8(14));
        for (uint8 i = 0; i < 14; i++) {
            bytecode[2 + uint256(i) * 2] = bytes1(i * 4);
        }
        bytecode[29 + 13 * 4] = bytes1(uint8(1));
        LibBytecode.checkNoOOBPointers(bytecode);

        bytecode[11] = bytes1(uint8(21933 >> 8));
        bytecode[12] = bytes1(uint8(21933 & 0xFF));
        vm.expectRevert(abi.encodeWithSelector(TruncatedHeader.selector, bytecode));
        this.checkNoOOBPointersExternal(bytecode);

        bytecode[11] = 0;
        bytecode[12] = bytes1(uint8(21));
        vm.expectRevert(abi.encodeWithSelector(TruncatedHeader.selector, bytecode));
        this.checkNoOOBPointersExternal(bytecode);
    }

    /// More than 127 sources overflows a `uint8` offset table size.
    function testCheckNoOOBPointersCorruptionsSourceCount128() external {
        this.testCheckNoOOBPointersHeaderTruncated(new bytes(800), 128, bytes32(0), 0);
        this.testCheckNoOOBPointersTrailingOffsetBytes(new bytes(800), hex"01", 128, bytes32(0));
        this.testCheckNoOOBPointersCorruptOffsetPointer(new bytes(800), 128, bytes32(0), 1);
        this.testCheckNoOOBPointersCorruptOpsCount(new bytes(800), 128, bytes32(0), 0xFF);
        this.testCheckNoOOBPointersInputsNotMonotonic(new bytes(800), 128, bytes32(0), 0, 0);
        this.testCheckNoOOBPointersOutputsNotMonotonic(new bytes(800), 128, bytes32(0), 0, 0);
    }

    /// Garbage that would push the last offset past two bytes is truncated so
    /// the shifted offsets stay well formed.
    function testCheckNoOOBPointersTrailingOffsetBytesOffsetOverflow() external {
        bytes memory bytecode = new bytes(0x20000);
        bytes32 fill = 0;
        for (uint256 i = 0; i < bytecode.length; i += 0x20) {
            fill = keccak256(abi.encode(fill));
            assembly ("memory-safe") {
                mstore(add(add(bytecode, 0x20), i), fill)
            }
        }
        this.testCheckNoOOBPointersTrailingOffsetBytes(bytecode, new bytes(0x7000), 127, bytes32(0));
    }
}
