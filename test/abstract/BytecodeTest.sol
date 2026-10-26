// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";

abstract contract BytecodeTest is Test {
    function conformBytecode(bytes memory bytecode, uint256 sourceCount, bytes32 seed) internal pure {
        unchecked {
            if (bytecode.length > 0) {
                // Max source count would be treating all the bytecode as empty sources.
                // ignore source count byte.
                // each source needs a 2 byte offset pointer and 4 byte header.
                uint256 maxSourceCount = (bytecode.length - 1) / 6;
                // Max source count can't exceed 256.
                maxSourceCount = bound(maxSourceCount, 0, 0xFF);

                // Source count is bounded by the max source count.
                sourceCount = bound(sourceCount, 0, maxSourceCount);

                // If source count is zero then return early with zero bytecode.
                if (sourceCount == 0) {
                    assembly ("memory-safe") {
                        mstore(bytecode, 1)
                        mstore8(add(bytecode, 0x20), 0)
                    }
                    return;
                }

                // Sourcecount is bound to max source count which is bound so
                // this typecast is safe.
                //forge-lint: disable-next-line(unsafe-typecast)
                bytecode[0] = bytes1(uint8(sourceCount));

                uint256 sourcesRelativeStart = 1 + sourceCount * 2;

                // Truncate the bytecode to be a multiple of 4 bytes after the
                // relative start.
                {
                    uint256 sourcesLengthMod4 = (bytecode.length - sourcesRelativeStart) % 4;
                    if (sourcesLengthMod4 != 0) {
                        assembly ("memory-safe") {
                            mstore(bytecode, sub(mload(bytecode), sourcesLengthMod4))
                        }
                    }
                    // Sanity check.
                    require((bytecode.length - sourcesRelativeStart) % 4 == 0, "bytecode length not multiple of 4");
                }

                // Randomly allocate ops to sources.
                uint256 sourceHeadersSize = sourceCount * 4;
                uint256 totalOpsCount = (bytecode.length - sourcesRelativeStart - sourceHeadersSize) / 4;

                // A source's ops count is a single header byte and its offset
                // pointer is two bytes, so a conforming bytecode holds at most
                // 0xFF ops per source and every source starts within 0xFFFF
                // bytes of the relative start. Truncate the bytecode to the
                // ops that fit both.
                {
                    uint256 maxOpsCount = sourceCount * 0xFF;
                    uint256 maxOpsCountByOffset = (0xFFFF - sourceHeadersSize) / 4;
                    if (maxOpsCountByOffset < maxOpsCount) {
                        maxOpsCount = maxOpsCountByOffset;
                    }
                    if (totalOpsCount > maxOpsCount) {
                        uint256 excessLength = (totalOpsCount - maxOpsCount) * 4;
                        assembly ("memory-safe") {
                            mstore(bytecode, sub(mload(bytecode), excessLength))
                        }
                        totalOpsCount = maxOpsCount;
                    }
                }

                // Randomly allocate ops to sources. A source that already holds
                // 0xFF ops passes its op to the next source with room.
                uint256[] memory opsPerSource = new uint256[](sourceCount);
                seed = keccak256(abi.encodePacked(seed));
                for (uint256 i = 0; i < totalOpsCount; i++) {
                    uint256 sourceIndex = uint256(seed) % sourceCount;
                    while (opsPerSource[sourceIndex] == 0xFF) {
                        sourceIndex = (sourceIndex + 1) % sourceCount;
                    }
                    opsPerSource[sourceIndex]++;
                    seed = keccak256(abi.encodePacked(seed));
                }

                // Set all the offset pointers.
                uint256 offset = 0;
                uint256 cursor = 1;
                for (uint256 i = 0; i < sourceCount; i++) {
                    // Offset being set one byte at a time so tyecast truncation
                    // is intentional.
                    //forge-lint: disable-next-line(unsafe-typecast)
                    bytecode[cursor] = bytes1(uint8(offset >> 8));
                    //forge-lint: disable-next-line(unsafe-typecast)
                    bytecode[cursor + 1] = bytes1(uint8(offset));
                    cursor += 2;

                    // Set the ops count for the source in the header.
                    uint256 headerPosition = sourcesRelativeStart + offset;
                    bytecode[headerPosition] = bytes1(uint8(opsPerSource[i]));
                    // allocation is the 2nd header byte.
                    uint256 allocation = uint8(bytecode[headerPosition + 1]);
                    // inputs is the 3rd header byte.
                    uint256 inputs = uint8(bytecode[headerPosition + 2]);
                    // outputs is the 4th header byte.
                    uint256 outputs = uint8(bytecode[headerPosition + 3]);

                    // inputs can't exceed outputs.
                    inputs = bound(inputs, 0, outputs);
                    // inputs is bound to outputs, which is a single byte, so
                    // this is a safe cast.
                    //forge-lint: disable-next-line(unsafe-typecast)
                    bytecode[headerPosition + 2] = bytes1(uint8(inputs));
                    // allocation can't be less than outputs.
                    allocation = bound(allocation, outputs, type(uint8).max);
                    // Allocation is bound so safe to typecast.
                    //forge-lint: disable-next-line(unsafe-typecast)
                    bytecode[headerPosition + 1] = bytes1(uint8(allocation));

                    offset += opsPerSource[i] * 4 + 4;
                }
                // Sanity check.
                require(offset == bytecode.length - sourcesRelativeStart, "offsets don't match bytecode length");
            }
        }
    }

    function randomSourceIndex(bytes memory bytecode, bytes32 seed) internal pure returns (uint256 sourceIndex) {
        // The case of empty sources means we can't select a source.
        vm.assume(bytecode.length > 1);
        uint256 sourceCount = uint8(bytecode[0]);

        // Pick a random source. Salt the seed to ensure we don't correlate with
        // usages of the seed elsewhere.
        seed = keccak256(abi.encodePacked(seed, "sourceIndex"));
        sourceIndex = uint256(seed) % sourceCount;
    }

    function randomSourcePosition(bytes memory bytecode, bytes32 seed) internal pure returns (uint256 sourcePosition) {
        uint256 sourceIndex = randomSourceIndex(bytecode, seed);
        uint256 sourceCount = uint8(bytecode[0]);
        uint256 sourceRelativeStart = 1 + sourceCount * 2;
        uint256 offsetPosition = sourceIndex * 2 + 1;
        uint256 offset = (uint256(uint8(bytecode[offsetPosition])) << 8) | uint256(uint8(bytecode[offsetPosition + 1]));

        sourcePosition = sourceRelativeStart + offset;
    }
}
