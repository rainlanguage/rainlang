// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibSubParse} from "../../../../src/lib/parse/LibSubParse.sol";
import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {LibBytecode, Pointer} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";
import {ISubParserV4} from "rain.interpreter.interface/interface/ISubParserV4.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {OPCODE_UNKNOWN, OPCODE_CONSTANT, OPCODE_CONTEXT} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {UnknownWord} from "../../../../src/error/ErrParse.sol";

/// @dev A sub parser that resolves any word by returning a context opcode with
/// no constants. Used to verify that subParseWords iterates multiple sources.
contract ContextReturningSubParser is ISubParserV4, IERC165 {
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(ISubParserV4).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function subParseLiteral2(bytes calldata) external pure override returns (bool, bytes32) {
        return (false, 0);
    }

    /// @notice Returns a context opcode (0,0) with no constants.
    function subParseWord2(bytes calldata) external pure override returns (bool, bytes memory, bytes32[] memory) {
        bytes memory bytecode = new bytes(4);
        // Safe: opcode constant and IO byte are small known values.
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[0] = bytes1(uint8(OPCODE_CONTEXT));
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[1] = bytes1(uint8(0x10)); // 0 inputs, 1 output
        bytecode[2] = bytes1(0); // row 0
        bytecode[3] = bytes1(0); // column 0
        return (true, bytecode, new bytes32[](0));
    }
}

/// @title LibSubParseSubParseWordsTest
/// @notice Direct unit tests for `LibSubParse.subParseWords`.
contract LibSubParseSubParseWordsTest is Test {
    using LibParseState for ParseState;
    using LibSubParse for ParseState;
    using LibParse for ParseState;
    using Strings for address;

    /// @notice Build a minimal single-source bytecode containing one 4-byte op.
    function buildSingleOpBytecode(uint8 opcode, uint8 ioByte, uint16 operand) internal pure returns (bytes memory) {
        return abi.encodePacked(
            uint8(1), // 1 source
            uint16(0), // relative offset = 0
            uint8(1), // ops count = 1
            uint8(0), // stack allocation
            uint8(0), // stack high water
            uint8(0), // stack inputs
            opcode,
            ioByte,
            operand
        );
    }

    /// @notice When bytecode has no sources, subParseWords returns unchanged
    /// bytecode and empty constants.
    function testSubParseWordsEmptyBytecode() external view {
        ParseState memory state = LibParseState.newState("", "", "", "");
        bytes memory bytecode = hex"00";
        (bytes memory result, bytes32[] memory constants) = state.subParseWords(bytecode);
        assertEq(result.length, bytecode.length);
        assertEq(constants.length, 0);
    }

    /// @notice When bytecode has one source with a known (non-unknown) opcode,
    /// subParseWords does not modify it.
    function testSubParseWordsSingleSourceNoUnknown() external view {
        ParseState memory state = LibParseState.newState("", "", "", "");
        bytes memory bytecode = buildSingleOpBytecode(
            // Safe: OPCODE_CONSTANT fits in uint8.
            //forge-lint: disable-next-line(unsafe-typecast)
            uint8(OPCODE_CONSTANT),
            0x10,
            0x0000
        );
        (bytes memory result, bytes32[] memory constants) = state.subParseWords(bytecode);
        assertEq(keccak256(result), keccak256(bytecode));
        assertEq(constants.length, 0);
    }

    /// @notice When a sub parser resolves a single unknown word via the full
    /// parse pipeline, the final bytecode does not contain OPCODE_UNKNOWN and
    /// the word is resolved to a valid opcode.
    function testSubParseWordsSingleSourceResolvesUnknown() external {
        ContextReturningSubParser sub = new ContextReturningSubParser();
        string memory src = string.concat("using-words-from ", address(sub).toHexString(), " _: some-word();");
        ParseState memory state = LibMetaFixture.newState(src);
        (bytes memory bytecode, bytes32[] memory constants) = state.parse();

        uint256 opsCount = LibBytecode.sourceOpsCount(bytecode, 0);
        assertEq(opsCount, 1, "Expected 1 op in source 0");

        Pointer sourcePtr = LibBytecode.sourcePointer(bytecode, 0);
        uint256 cursor = Pointer.unwrap(sourcePtr) + 4;
        uint8 opcode;
        assembly ("memory-safe") {
            opcode := byte(0, mload(cursor))
        }
        assertEq(uint256(opcode), OPCODE_CONTEXT);
        assertEq(constants.length, 0);
    }

    /// @notice When parsing an expression with two sources, subParseWords
    /// iterates over both and resolves unknown words in each.
    function testSubParseWordsTwoSourcesBothResolved() external {
        ContextReturningSubParser sub = new ContextReturningSubParser();
        string memory src =
            string.concat("using-words-from ", address(sub).toHexString(), " _: some-word(); _: another-word();");
        ParseState memory state = LibMetaFixture.newState(src);
        (bytes memory bytecode, bytes32[] memory constants) = state.parse();

        uint256 sourceCount = LibBytecode.sourceCount(bytecode);
        assertEq(sourceCount, 2, "Expected 2 sources");

        for (uint256 i = 0; i < sourceCount; i++) {
            uint256 opsCount = LibBytecode.sourceOpsCount(bytecode, i);
            assertEq(opsCount, 1);
            Pointer sourcePtr = LibBytecode.sourcePointer(bytecode, i);
            uint256 cursor = Pointer.unwrap(sourcePtr) + 4;
            uint8 opcode;
            assembly ("memory-safe") {
                opcode := byte(0, mload(cursor))
            }
            assertEq(uint256(opcode), OPCODE_CONTEXT);
        }
        assertEq(constants.length, 0);
    }

    /// @notice External wrapper so reverts can be caught via expectRevert.
    function externalParse(string memory src) external view returns (bytes memory, bytes32[] memory) {
        ParseState memory state = LibMetaFixture.newState(src);
        return state.parse();
    }

    /// @notice External wrapper for subParseWords so reverts can be caught.
    function externalSubParseWords(bytes memory bytecode) external view returns (bytes memory, bytes32[] memory) {
        ParseState memory state = LibParseState.newState("", "", "", "");
        return state.subParseWords(bytecode);
    }

    /// @notice When the sub parser rejects a word, parsing reverts with
    /// UnknownWord.
    function testSubParseWordsUnknownWordReverts() external {
        ContextReturningSubParser sub = new ContextReturningSubParser();

        // Mock subParseWord2 to reject all words.
        vm.mockCall(
            address(sub),
            abi.encodeWithSelector(ISubParserV4.subParseWord2.selector),
            abi.encode(false, bytes(""), new bytes32[](0))
        );

        string memory src = string.concat("using-words-from ", address(sub).toHexString(), " _: unknown-word();");

        vm.expectRevert();
        this.externalParse(src);
    }

    /// @notice When no sub parsers are registered and bytecode contains an
    /// unknown opcode, subParseWords reverts with UnknownWord.
    function testSubParseWordsNoSubParsersUnknownReverts() external {
        // Build bytecode with OPCODE_UNKNOWN directly.
        //forge-lint: disable-next-line(unsafe-typecast)
        bytes memory bytecode = buildSingleOpBytecode(uint8(OPCODE_UNKNOWN), 0x10, 0x0000);

        vm.expectRevert(abi.encodeWithSelector(UnknownWord.selector, ""));
        this.externalSubParseWords(bytecode);
    }

    /// @notice Multiple known opcodes in a single source are not modified.
    function testSubParseWordsMultipleKnownOpcodes() external view {
        ParseState memory state = LibParseState.newState("", "", "", "");
        // Safe: opcode constants fit in uint8.
        //forge-lint: disable-next-line(unsafe-typecast)
        bytes memory bytecode = abi.encodePacked(
            uint8(1), // 1 source
            uint16(0), // relative offset = 0
            uint8(2), // ops count = 2
            uint8(0),
            uint8(0),
            uint8(0), // stack tracker
            //forge-lint: disable-next-line(unsafe-typecast)
            uint8(OPCODE_CONSTANT),
            uint8(0x10),
            uint16(0),
            //forge-lint: disable-next-line(unsafe-typecast)
            uint8(OPCODE_CONTEXT),
            uint8(0x10),
            uint16(0)
        );
        (bytes memory result, bytes32[] memory constants) = state.subParseWords(bytecode);
        assertEq(keccak256(result), keccak256(bytecode));
        assertEq(constants.length, 0);
    }
}
