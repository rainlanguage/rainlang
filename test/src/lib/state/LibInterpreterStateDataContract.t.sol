// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibInterpreterStateDataContract} from "../../../../src/lib/state/LibInterpreterStateDataContract.sol";
import {InterpreterState} from "../../../../src/lib/state/LibInterpreterState.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {FullyQualifiedNamespace} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {IInterpreterStoreV3} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";
import {MemoryKV} from "rain.lib.memkv/lib/LibMemoryKV.sol";

/// @dev Wraps unsafeDeserialize as an external call to avoid
/// stack-too-deep from inlining the 9-field struct return.
contract LibInterpreterStateDataContractExtern {
    function deserialize(
        bytes memory serialized,
        uint256 sourceIndex,
        FullyQualifiedNamespace namespace,
        IInterpreterStoreV3 store,
        bytes32[][] memory context,
        bytes memory fs
    ) external pure returns (InterpreterState memory) {
        return LibInterpreterStateDataContract.unsafeDeserialize(serialized, sourceIndex, namespace, store, context, fs);
    }

    /// Deserializes and reads each stack's allocated length from memory.
    /// Must run inside the same call context as deserialization so that
    /// the stack pointers reference live memory.
    function deserializeStackLengths(bytes memory serialized) external pure returns (uint256[] memory) {
        InterpreterState memory state = LibInterpreterStateDataContract.unsafeDeserialize(
            serialized, 0, FullyQualifiedNamespace.wrap(0), IInterpreterStoreV3(address(0)), new bytes32[][](0), ""
        );
        uint256 count = state.stackBottoms.length;
        uint256[] memory lengths = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            Pointer bottom = state.stackBottoms[i];
            uint256 len;
            assembly ("memory-safe") {
                // Scan backwards from bottom for the array length word.
                // Stack layout is [length][slot0]...[slotN-1], bottom
                // points past slotN-1. At offset (length+1) words back
                // from bottom, mload == length.
                for { let offset := 2 } 1 { offset := add(offset, 1) } {
                    let v := mload(sub(bottom, mul(offset, 0x20)))
                    if eq(add(v, 1), offset) {
                        len := v
                        break
                    }
                }
            }
            lengths[i] = len;
        }
        return lengths;
    }
}

/// @title LibInterpreterStateDataContractTest
/// @notice Tests for LibInterpreterStateDataContract serialization and deserialization.
contract LibInterpreterStateDataContractTest is Test {
    LibInterpreterStateDataContractExtern internal immutable iExtern = new LibInterpreterStateDataContractExtern();

    function serialize(bytes memory bytecode, bytes32[] memory constants) internal pure returns (bytes memory) {
        uint256 size = LibInterpreterStateDataContract.serializeSize(bytecode, constants);
        bytes memory serialized;
        Pointer cursor;
        assembly ("memory-safe") {
            serialized := mload(0x40)
            mstore(serialized, size)
            mstore(0x40, add(serialized, add(0x20, size)))
            cursor := add(serialized, 0x20)
        }
        LibInterpreterStateDataContract.unsafeSerialize(cursor, bytecode, constants);
        return serialized;
    }

    /// Builds valid bytecode with a single source.
    function buildSingleSourceBytecode(uint8 opsCount, uint8 stackAllocation, uint8 inputs, uint8 outputs)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory result = abi.encodePacked(
            uint8(1), // sourceCount
            uint16(0), // relative offset source 0
            opsCount,
            stackAllocation,
            inputs,
            outputs
        );
        for (uint256 i = 0; i < opsCount; i++) {
            result = abi.encodePacked(
                result,
                uint8(0), // opcode index
                uint8(0x10), // ioByte: 0 inputs, 1 output
                uint16(0) // operand
            );
        }
        return result;
    }

    /// Builds valid bytecode with two sources.
    function buildTwoSourceBytecode(uint8 stackAllocation0, uint8 stackAllocation1)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory header = abi.encodePacked(uint8(2), uint16(0x0000), uint16(0x0008));
        bytes memory source0 =
            abi.encodePacked(uint8(1), stackAllocation0, uint8(0), uint8(1), uint8(0), uint8(0x10), uint16(0));
        bytes memory source1 =
            abi.encodePacked(uint8(1), stackAllocation1, uint8(0), uint8(1), uint8(0), uint8(0x10), uint16(0));
        return abi.encodePacked(header, source0, source1);
    }

    /// serializeSize returns the correct byte count for fuzzed inputs.
    function testSerializeSize(uint8 bytecodeLen, uint8 constantsLen) external pure {
        bytes memory bytecode = new bytes(bytecodeLen);
        bytes32[] memory constants = new bytes32[](constantsLen);

        uint256 size = LibInterpreterStateDataContract.serializeSize(bytecode, constants);
        uint256 expected = uint256(bytecodeLen) + uint256(constantsLen) * 32 + 64;
        assertEq(size, expected);
    }

    /// serializeSize with both empty bytecode and constants.
    function testSerializeSizeEmpty() external pure {
        bytes memory bytecode = new bytes(0);
        bytes32[] memory constants = new bytes32[](0);

        uint256 size = LibInterpreterStateDataContract.serializeSize(bytecode, constants);
        assertEq(size, 64);
    }

    /// Round-trip: serialize then deserialize, verify constants and bytecode.
    function testSerializeDeserializeRoundTrip() external view {
        bytes32[] memory constants = new bytes32[](3);
        constants[0] = bytes32(uint256(0xAA));
        constants[1] = bytes32(uint256(0xBB));
        constants[2] = bytes32(uint256(0xCC));

        bytes memory bytecode = buildSingleSourceBytecode(1, 2, 0, 1);
        bytes memory serialized = serialize(bytecode, constants);

        InterpreterState memory state = iExtern.deserialize(
            serialized, 0, FullyQualifiedNamespace.wrap(0), IInterpreterStoreV3(address(0)), new bytes32[][](0), ""
        );

        assertEq(state.constants.length, constants.length);
        for (uint256 i = 0; i < constants.length; i++) {
            assertEq(state.constants[i], constants[i]);
        }
        assertEq(keccak256(state.bytecode), keccak256(bytecode));
        assertEq(state.bytecode.length, bytecode.length);
    }

    /// Fuzzed round-trip: serialize then deserialize with arbitrary constants.
    function testSerializeDeserializeRoundTripFuzzed(bytes32[] memory constants) external view {
        bytes memory bytecode = buildSingleSourceBytecode(1, 2, 0, 1);
        bytes memory serialized = serialize(bytecode, constants);

        InterpreterState memory state = iExtern.deserialize(
            serialized, 0, FullyQualifiedNamespace.wrap(0), IInterpreterStoreV3(address(0)), new bytes32[][](0), ""
        );

        assertEq(state.constants.length, constants.length);
        for (uint256 i = 0; i < constants.length; i++) {
            assertEq(state.constants[i], constants[i]);
        }
        assertEq(keccak256(state.bytecode), keccak256(bytecode));
        assertEq(state.bytecode.length, bytecode.length);
    }

    /// Two-source round-trip: verify bytecode and constants survive serialize/deserialize.
    function testSerializeDeserializeTwoSourceRoundTrip(bytes32[] memory constants) external view {
        bytes memory bytecode = buildTwoSourceBytecode(3, 5);
        bytes memory serialized = serialize(bytecode, constants);

        InterpreterState memory state = iExtern.deserialize(
            serialized, 0, FullyQualifiedNamespace.wrap(0), IInterpreterStoreV3(address(0)), new bytes32[][](0), ""
        );

        assertEq(state.constants.length, constants.length);
        for (uint256 i = 0; i < constants.length; i++) {
            assertEq(state.constants[i], constants[i]);
        }
        assertEq(keccak256(state.bytecode), keccak256(bytecode));
        assertEq(state.bytecode.length, bytecode.length);
    }

    /// Round-trip with empty constants.
    function testSerializeDeserializeEmptyConstants() external view {
        bytes32[] memory constants = new bytes32[](0);
        bytes memory bytecode = buildSingleSourceBytecode(1, 1, 0, 1);
        bytes memory serialized = serialize(bytecode, constants);

        InterpreterState memory state = iExtern.deserialize(
            serialized, 0, FullyQualifiedNamespace.wrap(0), IInterpreterStoreV3(address(0)), new bytes32[][](0), ""
        );

        assertEq(state.constants.length, 0);
        assertEq(keccak256(state.bytecode), keccak256(bytecode));
    }

    /// sourceIndex is passed through to the deserialized state.
    function testUnsafeDeserializeSourceIndex(uint256 sourceIndex) external view {
        bytes memory serialized = serialize(buildSingleSourceBytecode(1, 1, 0, 1), new bytes32[](0));

        InterpreterState memory state = iExtern.deserialize(
            serialized,
            sourceIndex,
            FullyQualifiedNamespace.wrap(0),
            IInterpreterStoreV3(address(0)),
            new bytes32[][](0),
            ""
        );

        assertEq(state.sourceIndex, sourceIndex);
    }

    /// namespace is passed through to the deserialized state.
    function testUnsafeDeserializeNamespace(uint256 namespaceRaw) external view {
        bytes memory serialized = serialize(buildSingleSourceBytecode(1, 1, 0, 1), new bytes32[](0));

        InterpreterState memory state = iExtern.deserialize(
            serialized,
            0,
            FullyQualifiedNamespace.wrap(namespaceRaw),
            IInterpreterStoreV3(address(0)),
            new bytes32[][](0),
            ""
        );

        assertEq(FullyQualifiedNamespace.unwrap(state.namespace), namespaceRaw);
    }

    /// store address is passed through to the deserialized state.
    function testUnsafeDeserializeStore(address storeAddr) external view {
        bytes memory serialized = serialize(buildSingleSourceBytecode(1, 1, 0, 1), new bytes32[](0));

        InterpreterState memory state = iExtern.deserialize(
            serialized, 0, FullyQualifiedNamespace.wrap(0), IInterpreterStoreV3(storeAddr), new bytes32[][](0), ""
        );

        assertEq(address(state.store), storeAddr);
    }

    /// context is passed through to the deserialized state.
    function testUnsafeDeserializeContext(bytes32[][] memory context) external view {
        bytes memory serialized = serialize(buildSingleSourceBytecode(1, 1, 0, 1), new bytes32[](0));

        InterpreterState memory state = iExtern.deserialize(
            serialized, 0, FullyQualifiedNamespace.wrap(0), IInterpreterStoreV3(address(0)), context, ""
        );

        assertEq(state.context.length, context.length);
        for (uint256 i = 0; i < context.length; i++) {
            assertEq(state.context[i].length, context[i].length);
            for (uint256 j = 0; j < context[i].length; j++) {
                assertEq(state.context[i][j], context[i][j]);
            }
        }
    }

    /// fs is passed through to the deserialized state.
    function testUnsafeDeserializeFs(bytes memory fs) external view {
        bytes memory serialized = serialize(buildSingleSourceBytecode(1, 1, 0, 1), new bytes32[](0));

        InterpreterState memory state = iExtern.deserialize(
            serialized, 0, FullyQualifiedNamespace.wrap(0), IInterpreterStoreV3(address(0)), new bytes32[][](0), fs
        );

        assertEq(keccak256(state.fs), keccak256(fs));
    }

    /// stateKV is initialized to zero after deserialization.
    function testUnsafeDeserializeStateKVZero() external view {
        bytes memory serialized = serialize(buildSingleSourceBytecode(1, 1, 0, 1), new bytes32[](0));

        InterpreterState memory state = iExtern.deserialize(
            serialized, 0, FullyQualifiedNamespace.wrap(0), IInterpreterStoreV3(address(0)), new bytes32[][](0), ""
        );

        assertEq(MemoryKV.unwrap(state.stateKV), 0, "stateKV must be zero after deserialization");
    }

    /// Stack allocation matches the bytecode's declared stackAllocation.
    function testUnsafeDeserializeStackAllocation(uint8 stackAllocation) external view {
        vm.assume(stackAllocation > 0);

        bytes memory serialized = serialize(buildSingleSourceBytecode(1, stackAllocation, 0, 1), new bytes32[](0));
        uint256[] memory lengths = iExtern.deserializeStackLengths(serialized);

        assertEq(lengths.length, 1);
        assertEq(lengths[0], stackAllocation);
    }

    /// Stack allocation for two sources.
    function testUnsafeDeserializeTwoSourceStackAllocation(uint8 stackAllocation0, uint8 stackAllocation1)
        external
        view
    {
        vm.assume(stackAllocation0 > 0);
        vm.assume(stackAllocation1 > 0);

        bytes memory serialized =
            serialize(buildTwoSourceBytecode(stackAllocation0, stackAllocation1), new bytes32[](0));
        uint256[] memory lengths = iExtern.deserializeStackLengths(serialized);

        assertEq(lengths.length, 2);
        assertEq(lengths[0], stackAllocation0);
        assertEq(lengths[1], stackAllocation1);
    }
}
