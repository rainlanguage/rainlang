// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {BytecodeTest} from "test/abstract/BytecodeTest.sol";
import {LibBytecode} from "../../../../src/lib/bytecode/LibBytecode.sol";

contract LibBytecodeBytecodeToSourcesTest is BytecodeTest {
    /// Zero sources should return an empty array.
    function testBytecodeToSourcesZeroSources() external pure {
        bytes[] memory sources = LibBytecode.bytecodeToSources(hex"00");
        assertEq(sources.length, 0);
    }

    /// Empty bytecode should return an empty array.
    function testBytecodeToSourcesEmpty() external pure {
        bytes[] memory sources = LibBytecode.bytecodeToSources(hex"");
        assertEq(sources.length, 0);
    }

    /// Single source with zero opcodes should return one empty bytes.
    function testBytecodeToSourcesOneSourceZeroOps() external pure {
        // 1 source, offset 0, header: 0 ops, 0 alloc, 0 inputs, 0 outputs
        bytes[] memory sources = LibBytecode.bytecodeToSources(hex"01000000000000");
        assertEq(sources.length, 1);
        assertEq(sources[0].length, 0);
    }

    /// Single source with one opcode. Verify the byte-shuffling:
    /// new format byte 0 (opcode index) moves to byte 1, byte 0 becomes 0.
    function testBytecodeToSourcesOneSourceOneOp() external pure {
        // 1 source, offset 0, header: 1 op, 1 alloc, 0 inputs, 1 output
        // opcode: [0xAB, 0xCD, 0xEF, 0x12]
        bytes[] memory sources = LibBytecode.bytecodeToSources(hex"01000001010001ABCDEF12");
        assertEq(sources.length, 1);
        assertEq(sources[0].length, 4);
        // After shuffle: byte 0 (0xAB) moves to byte 1, byte 0 becomes 0
        assertEq(uint8(sources[0][0]), 0x00);
        assertEq(uint8(sources[0][1]), 0xAB);
        assertEq(uint8(sources[0][2]), 0xEF);
        assertEq(uint8(sources[0][3]), 0x12);
    }

    /// Single source with multiple opcodes. Verify every opcode is shuffled.
    function testBytecodeToSourcesOneSourceMultipleOps() external pure {
        // 1 source, offset 0, header: 3 ops, 3 alloc, 0 inputs, 3 outputs
        // opcodes: [AA,BB,CC,DD] [11,22,33,44] [FF,EE,DD,CC]
        bytes[] memory sources = LibBytecode.bytecodeToSources(hex"01000003030003AABBCCDD11223344FFEEDDCC");
        assertEq(sources.length, 1);
        assertEq(sources[0].length, 12);
        // Op 0: 0xAA moves to byte 1, byte 0 becomes 0.
        assertEq(uint8(sources[0][0]), 0x00);
        assertEq(uint8(sources[0][1]), 0xAA);
        assertEq(uint8(sources[0][2]), 0xCC);
        assertEq(uint8(sources[0][3]), 0xDD);
        // Op 1: 0x11 moves to byte 1, byte 0 becomes 0.
        assertEq(uint8(sources[0][4]), 0x00);
        assertEq(uint8(sources[0][5]), 0x11);
        assertEq(uint8(sources[0][6]), 0x33);
        assertEq(uint8(sources[0][7]), 0x44);
        // Op 2: 0xFF moves to byte 1, byte 0 becomes 0.
        assertEq(uint8(sources[0][8]), 0x00);
        assertEq(uint8(sources[0][9]), 0xFF);
        assertEq(uint8(sources[0][10]), 0xDD);
        assertEq(uint8(sources[0][11]), 0xCC);
    }

    /// Multiple sources with varying op counts.
    function testBytecodeToSourcesMultipleSources() external pure {
        // 2 sources
        // source 0: offset 0, 1 op, header [01, 01, 00, 01], opcode [AA, BB, CC, DD]
        // source 1: offset 8, 0 ops, header [00, 00, 00, 00]
        bytes[] memory sources = LibBytecode.bytecodeToSources(hex"020000000801010001AABBCCDD00000000");
        assertEq(sources.length, 2);
        assertEq(sources[0].length, 4);
        assertEq(sources[1].length, 0);
        // Verify byte-shuffling on source 0
        assertEq(uint8(sources[0][0]), 0x00);
        assertEq(uint8(sources[0][1]), 0xAA);
    }

    /// Fuzz: bytecodeToSources should produce one source per sourceCount,
    /// and each source length should equal opsCount * 4.
    function testBytecodeToSourcesFuzz(bytes memory bytecode, uint256 sourceCount, bytes32 seed) external pure {
        conformBytecode(bytecode, sourceCount, seed);
        LibBytecode.checkNoOOBPointers(bytecode);
        sourceCount = LibBytecode.sourceCount(bytecode);

        bytes[] memory sources = LibBytecode.bytecodeToSources(bytecode);
        assertEq(sources.length, sourceCount);

        for (uint256 i = 0; i < sourceCount; i++) {
            assertEq(sources[i].length, LibBytecode.sourceOpsCount(bytecode, i) * 4);
        }
    }
}
