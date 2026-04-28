// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {OPCODE_CONTEXT} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibSubParse} from "../../../../src/lib/parse/LibSubParse.sol";
import {ContextGridOverflow} from "../../../../src/error/ErrSubParse.sol";

contract LibSubParseSubParserContextTest is Test {
    function subParserContextExternal(uint256 column, uint256 row)
        external
        pure
        returns (bool, bytes memory, bytes32[] memory)
    {
        return LibSubParse.subParserContext(column, row);
    }

    /// Every possible valid context input will be sub parsed into context
    /// bytecode.
    function testLibSubParseSubParserContext(uint8 column, uint8 row) external pure {
        (bool success, bytes memory bytecode, bytes32[] memory constants) =
            LibSubParse.subParserContext(uint256(column), uint256(row));
        assertTrue(success);

        assertEq(bytecode.length, 4);
        assertEq(uint256(uint8(bytecode[0])), OPCODE_CONTEXT);
        // IO byte: 0 inputs, 1 output.
        assertEq(uint8(bytecode[1]), 0x10);
        assertEq(uint8(bytecode[2]), row);
        assertEq(uint8(bytecode[3]), column);

        assertEq(constants.length, 0);
    }

    /// Column must be <= 0xFF or the lib will error.
    function testLibSubParseSubParserContextColumnOverflow(uint256 column, uint8 row) external {
        column = bound(column, uint256(type(uint8).max) + 1, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(ContextGridOverflow.selector, column, uint256(row)));
        this.subParserContextExternal(column, uint256(row));
    }

    /// Row must be <= 0xFF or the lib will error.
    function testLibSubParseSubParserContextRowOverflow(uint8 column, uint256 row) external {
        row = bound(row, uint256(type(uint8).max) + 1, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(ContextGridOverflow.selector, uint256(column), row));
        this.subParserContextExternal(uint256(column), row);
    }
}
