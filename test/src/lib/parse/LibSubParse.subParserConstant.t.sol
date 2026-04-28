// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {OPCODE_CONSTANT} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibSubParse} from "../../../../src/lib/parse/LibSubParse.sol";
import {ConstantOpcodeConstantsHeightOverflow} from "../../../../src/error/ErrSubParse.sol";

contract LibSubParseSubParserConstantTest is Test {
    function subParserConstantExternal(uint256 constantsHeight, bytes32 value)
        external
        pure
        returns (bool, bytes memory, bytes32[] memory)
    {
        return LibSubParse.subParserConstant(constantsHeight, value);
    }

    /// Every possible valid constant input will be sub parsed into constant
    /// bytecode.
    function testLibSubParseSubParserConstant(uint16 constantsHeight, bytes32 value) external pure {
        (bool success, bytes memory bytecode, bytes32[] memory constants) =
            LibSubParse.subParserConstant(uint256(constantsHeight), value);
        assertTrue(success);

        assertEq(bytecode.length, 4);
        assertEq(uint256(uint8(bytecode[0])), OPCODE_CONSTANT);
        // IO byte: 0 inputs, 1 output.
        assertEq(uint8(bytecode[1]), 0x10);
        assertEq(uint16(uint8(bytecode[2])) << 8 | uint16(uint8(bytecode[3])), constantsHeight);

        assertEq(constants.length, 1);
        assertEq(constants[0], value);
    }

    /// Constants height must be <= 0xFFFF or the lib will error.
    function testLibSubParseSubParserConstantConstantsHeightOverflow(uint256 constantsHeight, bytes32 value) external {
        constantsHeight = bound(constantsHeight, uint256(type(uint16).max) + 1, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(ConstantOpcodeConstantsHeightOverflow.selector, constantsHeight));
        this.subParserConstantExternal(constantsHeight, value);
    }
}
