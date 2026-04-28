// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {OperandV2, OPCODE_EXTERN} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {
    IInterpreterExternV4,
    ExternDispatchV2,
    EncodedExternDispatchV2
} from "rain.interpreter.interface/interface/IInterpreterExternV4.sol";
import {LibSubParse} from "../../../../src/lib/parse/LibSubParse.sol";
import {LibExtern} from "../../../../src/lib/extern/LibExtern.sol";
import {ExternDispatchConstantsHeightOverflow} from "../../../../src/error/ErrSubParse.sol";

contract LibSubParseSubParserExternTest is Test {
    function subParserExternExternal(
        IInterpreterExternV4 extern,
        uint256 constantsHeight,
        uint256 inputsOutputs,
        OperandV2 operand,
        uint256 opcodeIndex
    ) external pure returns (bool, bytes memory, bytes32[] memory) {
        return LibSubParse.subParserExtern(extern, constantsHeight, inputsOutputs, operand, opcodeIndex);
    }

    /// Every possible valid extern input will be sub parsed into extern
    /// bytecode.
    function testLibSubParseSubParserExtern(
        IInterpreterExternV4 extern,
        uint8 constantsHeight,
        uint8 inputs,
        uint8 outputs,
        uint16 operandValue,
        uint8 opcodeIndex
    ) external pure {
        inputs = uint8(bound(inputs, 0, 0xF));
        outputs = uint8(bound(outputs, 0, 0xF));
        (bool success, bytes memory bytecode, bytes32[] memory constants) = LibSubParse.subParserExtern(
            extern,
            uint256(constantsHeight),
            uint256(outputs) << 4 | uint256(inputs),
            OperandV2.wrap(bytes32(uint256(operandValue))),
            uint256(opcodeIndex)
        );
        assertTrue(success);

        assertEq(bytecode.length, 4);
        assertEq(uint256(uint8(bytecode[0])), OPCODE_EXTERN);
        assertEq(uint8(bytecode[1]) & 0x0F, inputs);
        assertEq(uint8(bytecode[1]) >> 4, outputs);
        assertEq(uint16(uint8(bytecode[2])) << 8 | uint16(uint8(bytecode[3])), constantsHeight);

        assertEq(constants.length, 1);
        (IInterpreterExternV4 externDecoded, ExternDispatchV2 externDispatchDecoded) =
            LibExtern.decodeExternCall(EncodedExternDispatchV2.wrap(constants[0]));
        assertEq(address(extern), address(externDecoded));
        (uint256 opcodeIndexDecoded, OperandV2 operandDecoded) = LibExtern.decodeExternDispatch(externDispatchDecoded);
        assertEq(opcodeIndexDecoded, opcodeIndex);
        assertEq(OperandV2.unwrap(operandDecoded), bytes32(uint256(operandValue)));
    }

    /// Constants height must be less than 256 or the lib will error.
    function testLibSubParseSubParserExternConstantsHeightOverflow(
        IInterpreterExternV4 extern,
        uint256 constantsHeight,
        uint8 inputsByte,
        uint8 outputsByte,
        uint16 operandValue,
        uint8 opcodeIndex
    ) external {
        constantsHeight = bound(constantsHeight, uint256(type(uint16).max) + 1, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(ExternDispatchConstantsHeightOverflow.selector, constantsHeight));
        (bool success, bytes memory bytecode, bytes32[] memory constants) = this.subParserExternExternal(
            extern,
            constantsHeight,
            uint256(outputsByte) << 4 | uint256(inputsByte),
            OperandV2.wrap(bytes32(uint256(operandValue))),
            uint256(opcodeIndex)
        );
        (success, bytecode, constants);
    }
}
