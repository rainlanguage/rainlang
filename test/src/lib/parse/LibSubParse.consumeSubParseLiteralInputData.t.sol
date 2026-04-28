// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibSubParse} from "../../../../src/lib/parse/LibSubParse.sol";

/// @title LibSubParseConsumeSubParseLiteralInputDataTest
/// @notice Direct unit tests for `LibSubParse.consumeSubParseLiteralInputData`.
/// This function unpacks the dispatch and body memory region pointers from an
/// encoded `bytes` payload. The format is:
///   [dispatchLength:2 bytes][dispatch:dispatchLength bytes][body:remaining bytes]
/// It returns memory pointers (dispatchStart, bodyStart, bodyEnd) that
/// partition the data into dispatch and body regions.
contract LibSubParseConsumeSubParseLiteralInputDataTest is Test {
    /// @notice Build encoded literal input data from dispatch and body.
    function buildLiteralData(bytes memory dispatch, bytes memory body) internal pure returns (bytes memory) {
        return bytes.concat(bytes2(uint16(dispatch.length)), dispatch, body);
    }

    /// @notice Basic: dispatch and body are correctly partitioned.
    function testConsumeLiteralInputDataBasic() external pure {
        bytes memory dispatch = bytes("foo");
        bytes memory body = bytes("bar");
        bytes memory data = buildLiteralData(dispatch, body);

        (uint256 dispatchStart, uint256 bodyStart, uint256 bodyEnd) = LibSubParse.consumeSubParseLiteralInputData(data);

        // Dispatch region length should be 3.
        assertEq(bodyStart - dispatchStart, dispatch.length);
        // Body region length should be 3.
        assertEq(bodyEnd - bodyStart, body.length);
        // Total data region should be dispatch + body.
        assertEq(bodyEnd - dispatchStart, dispatch.length + body.length);
    }

    /// @notice Verify the actual bytes in the dispatch region by reading from
    /// memory.
    function testConsumeLiteralInputDataDispatchContent() external pure {
        bytes memory dispatch = bytes("abc");
        bytes memory body = bytes("xyz");
        bytes memory data = buildLiteralData(dispatch, body);

        (uint256 dispatchStart, uint256 bodyStart,) = LibSubParse.consumeSubParseLiteralInputData(data);

        // Read dispatch bytes from memory and compare.
        uint256 dispatchLength = bodyStart - dispatchStart;
        bytes memory readDispatch = new bytes(dispatchLength);
        assembly ("memory-safe") {
            let src := dispatchStart
            let dst := add(readDispatch, 0x20)
            for { let i := 0 } lt(i, dispatchLength) { i := add(i, 1) } {
                mstore8(add(dst, i), byte(0, mload(add(src, i))))
            }
        }
        assertEq(keccak256(readDispatch), keccak256(dispatch));
    }

    /// @notice Verify the actual bytes in the body region by reading from
    /// memory.
    function testConsumeLiteralInputDataBodyContent() external pure {
        bytes memory dispatch = bytes("abc");
        bytes memory body = bytes("xyz");
        bytes memory data = buildLiteralData(dispatch, body);

        (, uint256 bodyStart, uint256 bodyEnd) = LibSubParse.consumeSubParseLiteralInputData(data);

        // Read body bytes from memory and compare.
        uint256 bodyLength = bodyEnd - bodyStart;
        bytes memory readBody = new bytes(bodyLength);
        assembly ("memory-safe") {
            let src := bodyStart
            let dst := add(readBody, 0x20)
            for { let i := 0 } lt(i, bodyLength) { i := add(i, 1) } {
                mstore8(add(dst, i), byte(0, mload(add(src, i))))
            }
        }
        assertEq(keccak256(readBody), keccak256(body));
    }

    /// @notice Empty body: body region has zero length.
    function testConsumeLiteralInputDataEmptyBody() external pure {
        bytes memory dispatch = bytes("dispatch");
        bytes memory body = bytes("");
        bytes memory data = buildLiteralData(dispatch, body);

        (uint256 dispatchStart, uint256 bodyStart, uint256 bodyEnd) = LibSubParse.consumeSubParseLiteralInputData(data);

        assertEq(bodyStart - dispatchStart, dispatch.length);
        assertEq(bodyEnd - bodyStart, 0);
    }

    /// @notice Single-byte dispatch, empty body.
    function testConsumeLiteralInputDataMinimal() external pure {
        bytes memory dispatch = bytes("x");
        bytes memory body = bytes("");
        bytes memory data = buildLiteralData(dispatch, body);

        (uint256 dispatchStart, uint256 bodyStart, uint256 bodyEnd) = LibSubParse.consumeSubParseLiteralInputData(data);

        assertEq(bodyStart - dispatchStart, 1);
        assertEq(bodyEnd - bodyStart, 0);
    }

    /// @notice Fuzz: dispatch and body lengths are preserved across arbitrary
    /// inputs.
    function testConsumeLiteralInputDataFuzz(bytes memory dispatch, bytes memory body) external pure {
        // Bound dispatch length to valid uint16 range and keep reasonable.
        vm.assume(dispatch.length <= 1000);
        vm.assume(body.length <= 1000);
        vm.assume(dispatch.length > 0);

        bytes memory data = buildLiteralData(dispatch, body);

        (uint256 dispatchStart, uint256 bodyStart, uint256 bodyEnd) = LibSubParse.consumeSubParseLiteralInputData(data);

        assertEq(bodyStart - dispatchStart, dispatch.length);
        assertEq(bodyEnd - bodyStart, body.length);
    }

    /// @notice Roundtrip: build data with buildLiteralData, unpack with
    /// consumeSubParseLiteralInputData, and verify both dispatch and body
    /// content are preserved byte-for-byte.
    function testConsumeLiteralInputDataRoundtrip() external pure {
        bytes memory dispatch = bytes("hello");
        bytes memory body = bytes("world");
        bytes memory data = buildLiteralData(dispatch, body);

        (uint256 dispatchStart, uint256 bodyStart, uint256 bodyEnd) = LibSubParse.consumeSubParseLiteralInputData(data);

        uint256 dispatchLength = dispatch.length;
        uint256 bodyLength = body.length;

        assertEq(bodyStart - dispatchStart, dispatchLength);
        assertEq(bodyEnd - bodyStart, bodyLength);

        // Verify content by reading from the returned memory pointers.
        bytes memory readDispatch = new bytes(dispatchLength);
        bytes memory readBody = new bytes(bodyLength);
        assembly ("memory-safe") {
            let src := dispatchStart
            let dst := add(readDispatch, 0x20)
            for { let i := 0 } lt(i, dispatchLength) { i := add(i, 1) } {
                mstore8(add(dst, i), byte(0, mload(add(src, i))))
            }

            src := bodyStart
            dst := add(readBody, 0x20)
            for { let i := 0 } lt(i, bodyLength) { i := add(i, 1) } {
                mstore8(add(dst, i), byte(0, mload(add(src, i))))
            }
        }
        assertEq(keccak256(readDispatch), keccak256(dispatch));
        assertEq(keccak256(readBody), keccak256(body));
    }
}
