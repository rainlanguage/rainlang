// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibSubParse} from "../../../../src/lib/parse/LibSubParse.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";

/// @title LibSubParseConsumeSubParseWordInputDataTest
/// @notice Direct unit tests for `LibSubParse.consumeSubParseWordInputData`.
/// This function unpacks a sub-parse header from encoded `bytes` input,
/// extracting the constants height, IO byte, and constructing a fresh
/// `ParseState` from the remaining word string and provided meta/operand
/// handler bytes.
///
/// The input data format is:
///   [constantsHeight:2 bytes][ioByte:1 byte][wordLength:2 bytes][wordData:wordLength bytes][operandValues...]
contract LibSubParseConsumeSubParseWordInputDataTest is Test {
    /// @notice Build sub-parse word input data from components.
    /// @param constantsHeight The constants height (2 bytes).
    /// @param ioByte The IO byte (1 byte).
    /// @param word The word string.
    /// @param operandValues The operand values array (encoded as 32-byte words
    /// with a leading length word).
    function buildInputData(uint16 constantsHeight, uint8 ioByte, bytes memory word, bytes32[] memory operandValues)
        internal
        pure
        returns (bytes memory)
    {
        // Encode the operand values as raw memory: length word + value words.
        // Cannot alias bytes32[] as bytes directly because the length field
        // semantics differ (element count vs byte count). Encode manually.
        bytes memory operandBytes = new bytes(32 + operandValues.length * 32);
        assembly ("memory-safe") {
            // Write the element count as the first 32 bytes (matches bytes32[] ABI).
            mstore(add(operandBytes, 0x20), mload(operandValues))
            // Copy the value words.
            for { let i := 0 } lt(i, mload(operandValues)) { i := add(i, 1) } {
                mstore(add(operandBytes, add(0x40, mul(i, 0x20))), mload(add(operandValues, add(0x20, mul(i, 0x20)))))
            }
        }
        return bytes.concat(bytes2(constantsHeight), bytes1(ioByte), bytes2(uint16(word.length)), word, operandBytes);
    }

    /// @notice Basic happy path: extract constants height, IO byte, and word
    /// from a well-formed input.
    function testConsumeSubParseWordInputDataBasic() external pure {
        bytes memory word = bytes("hello");
        bytes32[] memory operandValues = new bytes32[](0);
        bytes memory data = buildInputData(42, 0x31, word, operandValues);
        bytes memory meta = hex"aabb";
        bytes memory operandHandlers = hex"ccdd";

        (uint256 constantsHeight, uint256 ioByte, ParseState memory state) =
            LibSubParse.consumeSubParseWordInputData(data, meta, operandHandlers);

        assertEq(constantsHeight, 42);
        assertEq(ioByte, 0x31);
        // The state's data should be the word.
        assertEq(keccak256(state.data), keccak256(word));
        // The state's meta should be what we passed.
        assertEq(keccak256(state.meta), keccak256(meta));
        // The state's operandHandlers should be what we passed.
        assertEq(keccak256(state.operandHandlers), keccak256(operandHandlers));
    }

    /// @notice Fuzz: constants height is correctly extracted across the full
    /// uint16 range.
    function testConsumeSubParseWordInputDataFuzzConstantsHeight(uint16 constantsHeight) external pure {
        bytes memory word = bytes("w");
        bytes32[] memory operandValues = new bytes32[](0);
        bytes memory data = buildInputData(constantsHeight, 0x00, word, operandValues);

        (uint256 extractedHeight,,) = LibSubParse.consumeSubParseWordInputData(data, "", "");
        assertEq(extractedHeight, uint256(constantsHeight));
    }

    /// @notice Fuzz: IO byte is correctly extracted across the full uint8
    /// range.
    function testConsumeSubParseWordInputDataFuzzIOByte(uint8 ioByte) external pure {
        bytes memory word = bytes("w");
        bytes32[] memory operandValues = new bytes32[](0);
        bytes memory data = buildInputData(0, ioByte, word, operandValues);

        (, uint256 extractedIOByte,) = LibSubParse.consumeSubParseWordInputData(data, "", "");
        assertEq(extractedIOByte, uint256(ioByte));
    }

    /// @notice Maximum constants height (0xFFFF) is correctly extracted.
    function testConsumeSubParseWordInputDataMaxConstantsHeight() external pure {
        bytes memory word = bytes("x");
        bytes32[] memory operandValues = new bytes32[](0);
        bytes memory data = buildInputData(0xFFFF, 0x00, word, operandValues);

        (uint256 extractedHeight,,) = LibSubParse.consumeSubParseWordInputData(data, "", "");
        assertEq(extractedHeight, 0xFFFF);
    }

    /// @notice Empty word: zero-length word string is handled correctly.
    function testConsumeSubParseWordInputDataEmptyWord() external pure {
        bytes memory word = bytes("");
        bytes32[] memory operandValues = new bytes32[](0);
        bytes memory data = buildInputData(5, 0x10, word, operandValues);

        (uint256 constantsHeight, uint256 ioByte, ParseState memory state) =
            LibSubParse.consumeSubParseWordInputData(data, "", "");

        assertEq(constantsHeight, 5);
        assertEq(ioByte, 0x10);
        assertEq(state.data.length, 0);
    }

    /// @notice Longer word: the full word content is preserved in the state.
    function testConsumeSubParseWordInputDataLongerWord() external pure {
        bytes memory word = bytes("ref-extern-inc");
        bytes32[] memory operandValues = new bytes32[](0);
        bytes memory data = buildInputData(100, 0x21, word, operandValues);

        (uint256 constantsHeight, uint256 ioByte, ParseState memory state) =
            LibSubParse.consumeSubParseWordInputData(data, "", "");

        assertEq(constantsHeight, 100);
        assertEq(ioByte, 0x21);
        assertEq(keccak256(state.data), keccak256(word));
    }

    /// @notice Non-empty operand values round-trip through the input data.
    function testConsumeSubParseWordInputDataWithOperands() external pure {
        bytes memory word = bytes("op");
        bytes32[] memory operandValues = new bytes32[](2);
        operandValues[0] = bytes32(uint256(0xaa));
        operandValues[1] = bytes32(uint256(0xbb));
        bytes memory data = buildInputData(7, 0x42, word, operandValues);

        (uint256 constantsHeight, uint256 ioByte, ParseState memory state) =
            LibSubParse.consumeSubParseWordInputData(data, "", "");

        assertEq(constantsHeight, 7);
        assertEq(ioByte, 0x42);
        assertEq(keccak256(state.data), keccak256(word));
        assertEq(state.operandValues.length, 2);
        assertEq(state.operandValues[0], bytes32(uint256(0xaa)));
        assertEq(state.operandValues[1], bytes32(uint256(0xbb)));
    }
}
