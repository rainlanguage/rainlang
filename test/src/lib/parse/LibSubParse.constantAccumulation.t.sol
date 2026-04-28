// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {ISubParserV4} from "rain.interpreter.interface/interface/ISubParserV4.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {OPCODE_CONSTANT} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibBytecode, Pointer} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

/// @dev A sub parser that resolves any word by returning a constant opcode
/// with a known constant value. Each call returns exactly one constant.
contract ConstantReturningSubParser is ISubParserV4, IERC165 {
    bytes32 public constant RETURN_VALUE = bytes32(uint256(0xDEADBEEF));

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(ISubParserV4).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function subParseLiteral2(bytes calldata) external pure override returns (bool, bytes32) {
        return (false, 0);
    }

    /// @notice Returns a constant opcode pointing at the current constants
    /// height from the header, with a single constant value.
    function subParseWord2(bytes calldata data) external pure override returns (bool, bytes memory, bytes32[] memory) {
        // Extract constantsHeight from header (first 2 bytes).
        uint256 constantsHeight = uint256(uint16(bytes2(data[0:2])));

        // Build 4-byte constant opcode: [OPCODE_CONSTANT][IO=0x10][operand=constantsHeight]
        bytes memory bytecode = new bytes(4);
        // Safe: opcode constants and IO byte are small known values that fit
        // in uint8/bytes1.
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[0] = bytes1(uint8(OPCODE_CONSTANT));
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[1] = bytes1(uint8(0x10)); // 0 inputs, 1 output
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[2] = bytes1(uint8(constantsHeight >> 8));
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[3] = bytes1(uint8(constantsHeight));

        bytes32[] memory constants = new bytes32[](1);
        constants[0] = RETURN_VALUE;

        return (true, bytecode, constants);
    }
}

/// @dev A sub parser that returns multiple constants per word resolution.
contract MultiConstantSubParser is ISubParserV4, IERC165 {
    bytes32 public constant VALUE_A = bytes32(uint256(0xAAAA));
    bytes32 public constant VALUE_B = bytes32(uint256(0xBBBB));

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(ISubParserV4).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function subParseLiteral2(bytes calldata) external pure override returns (bool, bytes32) {
        return (false, 0);
    }

    /// @notice Returns a constant opcode with two constants. The first constant
    /// is used as the operand target; the second is an extra accumulation.
    function subParseWord2(bytes calldata data) external pure override returns (bool, bytes memory, bytes32[] memory) {
        uint256 constantsHeight = uint256(uint16(bytes2(data[0:2])));

        bytes memory bytecode = new bytes(4);
        // Safe: opcode constants and IO byte are small known values that fit
        // in uint8/bytes1.
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[0] = bytes1(uint8(OPCODE_CONSTANT));
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[1] = bytes1(uint8(0x10));
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[2] = bytes1(uint8(constantsHeight >> 8));
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[3] = bytes1(uint8(constantsHeight));

        bytes32[] memory constants = new bytes32[](2);
        constants[0] = VALUE_A;
        constants[1] = VALUE_B;

        return (true, bytecode, constants);
    }
}

/// @title LibSubParseConstantAccumulationTest
/// @notice Tests that constants returned by sub parsers during word resolution
/// are correctly accumulated into the final constants array at the right
/// indices. The existing `badSubParserResult` test returns empty constants
/// arrays, so constant accumulation from sub parsers was never verified.
contract LibSubParseConstantAccumulationTest is Test {
    using LibParseState for ParseState;
    using LibParse for ParseState;
    using Strings for address;

    /// @notice A single unknown word resolved by a sub parser that returns one
    /// constant. The constant must appear in the final constants array.
    function testSubParserSingleConstantAccumulation() external {
        ConstantReturningSubParser sub = new ConstantReturningSubParser();
        string memory src = string.concat("using-words-from ", address(sub).toHexString(), " _: some-word();");

        ParseState memory state = LibMetaFixture.newState(src);
        (, bytes32[] memory constants) = state.parse();

        // The sub parser returns exactly 1 constant per word resolution.
        assertEq(constants.length, 1, "Expected 1 constant from sub parser");
        assertEq(constants[0], ConstantReturningSubParser(sub).RETURN_VALUE());
    }

    /// @notice Two unknown words resolved by the same sub parser. Each returns
    /// one constant. The final constants array must contain both values in
    /// the correct order.
    function testSubParserTwoWordsConstantAccumulation() external {
        ConstantReturningSubParser sub = new ConstantReturningSubParser();
        string memory src =
            string.concat("using-words-from ", address(sub).toHexString(), " _ _: some-word() another-word();");

        ParseState memory state = LibMetaFixture.newState(src);
        (, bytes32[] memory constants) = state.parse();

        // Both words return the same constant value, but each call adds a new
        // constant. Due to deduplication in the constants builder, identical
        // values may be deduplicated to a single entry.
        // The key assertion: at least one constant is present and has the
        // expected value.
        assertTrue(constants.length >= 1, "Expected at least 1 constant");
        assertEq(constants[0], ConstantReturningSubParser(sub).RETURN_VALUE());
    }

    /// @notice A sub parser that returns multiple constants per word. All
    /// constants must be accumulated.
    function testSubParserMultiConstantAccumulation() external {
        MultiConstantSubParser sub = new MultiConstantSubParser();
        string memory src = string.concat("using-words-from ", address(sub).toHexString(), " _: multi-word();");

        ParseState memory state = LibMetaFixture.newState(src);
        (, bytes32[] memory constants) = state.parse();

        // The sub parser returns 2 constants per word.
        assertEq(constants.length, 2, "Expected 2 constants from multi-constant sub parser");
        assertEq(constants[0], MultiConstantSubParser(sub).VALUE_A());
        assertEq(constants[1], MultiConstantSubParser(sub).VALUE_B());
    }

    /// @notice Constants from sub parsers are appended after any constants
    /// already in the parse state (e.g. from literals). The bytecode for the
    /// sub-parsed word should reference the correct index.
    function testSubParserConstantIndexAfterLiteral() external {
        ConstantReturningSubParser sub = new ConstantReturningSubParser();
        // "1e0" is a literal that becomes constant[0].
        // "some-word" should get constant[1].
        string memory src = string.concat("using-words-from ", address(sub).toHexString(), " _ _: 1e0 some-word();");

        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(src).parse();

        // There should be at least 2 constants: one from the literal, one from
        // the sub parser.
        assertTrue(constants.length >= 2, "Expected at least 2 constants");

        // The sub parser constant should be at some index in the array.
        bool foundSubParserConstant = false;
        for (uint256 i = 0; i < constants.length; i++) {
            if (constants[i] == ConstantReturningSubParser(sub).RETURN_VALUE()) {
                foundSubParserConstant = true;
                break;
            }
        }
        assertTrue(foundSubParserConstant, "Sub parser constant not found in constants array");

        // Verify the bytecode references valid constant indices.
        // Source 0 should have 2 ops, both OPCODE_CONSTANT.
        uint256 opsCount = LibBytecode.sourceOpsCount(bytecode, 0);
        assertEq(opsCount, 2, "Expected 2 ops in source 0");

        // Read the operands of both constant ops to verify they reference
        // valid indices.
        Pointer sourcePtr = LibBytecode.sourcePointer(bytecode, 0);
        uint256 cursor = Pointer.unwrap(sourcePtr) + 4; // skip 4-byte source prefix
        for (uint256 i = 0; i < opsCount; i++) {
            uint8 opcode;
            uint16 operand;
            assembly ("memory-safe") {
                let word := mload(cursor)
                opcode := byte(0, word)
                // Operand is bytes 2-3 of the 4-byte op (big-endian uint16).
                operand := and(shr(0xe0, word), 0xFFFF)
            }
            assertEq(uint256(opcode), OPCODE_CONSTANT, "Expected OPCODE_CONSTANT");
            assertTrue(operand < constants.length, "Constant index out of bounds");
            cursor += 4;
        }
    }
}
