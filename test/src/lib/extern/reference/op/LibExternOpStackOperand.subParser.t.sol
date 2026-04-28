// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {OPCODE_CONSTANT, OperandV2} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibExternOpStackOperand} from "../../../../../../src/lib/extern/reference/op/LibExternOpStackOperand.sol";

contract LibExternOpStackOperandSubParserTest is Test {
    /// subParser must return a constant opcode referencing the operand value,
    /// with constantsHeight used as the constant index. Fuzz all inputs to
    /// confirm the operand value is stored as a constant and the bytecode
    /// targets the correct index.
    function testSubParserStackOperand(uint16 constantsHeight, uint256 ioByte, OperandV2 operand) external pure {
        (bool success, bytes memory bytecode, bytes32[] memory constants) =
            LibExternOpStackOperand.subParser(uint256(constantsHeight), ioByte, operand);
        assertTrue(success);
        assertEq(bytecode.length, 4);
        assertEq(uint256(uint8(bytecode[0])), OPCODE_CONSTANT);
        // IO byte: 0 inputs, 1 output.
        assertEq(uint8(bytecode[1]), 0x10);
        // Low 2 bytes encode the constants index (constantsHeight).
        assertEq((uint16(uint8(bytecode[2])) << 8) | uint16(uint8(bytecode[3])), constantsHeight);
        // The operand value is stored as a single constant.
        assertEq(constants.length, 1);
        assertEq(constants[0], OperandV2.unwrap(operand));
    }
}
