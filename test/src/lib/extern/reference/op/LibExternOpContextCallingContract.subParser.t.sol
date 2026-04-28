// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {OPCODE_CONTEXT, OperandV2} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {
    CONTEXT_BASE_COLUMN,
    CONTEXT_BASE_ROW_CALLING_CONTRACT
} from "rain.interpreter.interface/lib/caller/LibContext.sol";
import {
    LibExternOpContextCallingContract
} from "../../../../../../src/lib/extern/reference/op/LibExternOpContextCallingContract.sol";

contract LibExternOpContextCallingContractSubParserTest is Test {
    /// subParser must return context bytecode targeting column 0, row 1
    /// (the calling contract row) regardless of the inputs passed.
    function testSubParserCallingContract(uint256 constantsHeight, uint256 ioByte, OperandV2 operand) external pure {
        (bool success, bytes memory bytecode, bytes32[] memory constants) =
            LibExternOpContextCallingContract.subParser(constantsHeight, ioByte, operand);
        assertTrue(success);
        assertEq(bytecode.length, 4);
        assertEq(uint256(uint8(bytecode[0])), OPCODE_CONTEXT);
        // IO byte: 0 inputs, 1 output.
        assertEq(uint8(bytecode[1]), 0x10);
        assertEq(uint8(bytecode[2]), CONTEXT_BASE_ROW_CALLING_CONTRACT);
        assertEq(uint8(bytecode[3]), CONTEXT_BASE_COLUMN);
        assertEq(constants.length, 0);
    }
}
