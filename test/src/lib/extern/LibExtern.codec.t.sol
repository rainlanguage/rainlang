// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {OperandV2} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {
    LibExtern,
    EncodedExternDispatchV2,
    ExternDispatchV2,
    IInterpreterExternV4
} from "../../../../src/lib/extern/LibExtern.sol";

/// @title LibExternCodecTest
/// @notice Tests the encoding and decoding of the types associated with extern contract
/// calling and internal dispatch.
contract LibExternCodecTest is Test {
    /// Ensure `encodeExternDispatch` encodes the opcode and operand correctly.
    function testLibExternCodecEncodeExternDispatch(uint256 opcode, bytes32 operand) external pure {
        opcode = bound(opcode, 0, type(uint16).max);
        operand = bytes32(bound(uint256(operand), 0, type(uint16).max));
        ExternDispatchV2 dispatch = LibExtern.encodeExternDispatch(opcode, OperandV2.wrap(bytes32(operand)));
        (uint256 decodedOpcode, OperandV2 decodedOperand) = LibExtern.decodeExternDispatch(dispatch);
        assertEq(decodedOpcode, opcode);
        assertEq(OperandV2.unwrap(decodedOperand), operand);
    }

    /// Ensure `encodeExternCall` encodes the address and dispatch correctly.
    function testLibExternCodecEncodeExternCall(string memory name, uint256 opcode, bytes32 operand) external {
        opcode = bound(opcode, 0, type(uint16).max);
        operand = bytes32(bound(uint256(operand), 0, type(uint16).max));
        IInterpreterExternV4 extern = IInterpreterExternV4(makeAddr(name));
        ExternDispatchV2 dispatch = LibExtern.encodeExternDispatch(opcode, OperandV2.wrap(operand));
        EncodedExternDispatchV2 encoded = LibExtern.encodeExternCall(extern, dispatch);
        (IInterpreterExternV4 decodedExtern, ExternDispatchV2 decodedDispatch) = LibExtern.decodeExternCall(encoded);
        assertEq(uint256(uint160(address(decodedExtern))), uint256(uint160(address(extern))));
        assertEq(ExternDispatchV2.unwrap(decodedDispatch), ExternDispatchV2.unwrap(dispatch));
        (uint256 decodedOpcode, OperandV2 decodedOperand) = LibExtern.decodeExternDispatch(decodedDispatch);
        assertEq(decodedOpcode, opcode);
        assertEq(OperandV2.unwrap(decodedOperand), operand);
    }

    /// Standalone decode of `ExternDispatchV2` from a manually constructed
    /// word, independent of `encodeExternDispatch`. Catches symmetric bugs
    /// where encode and decode are both wrong in the same way.
    function testDecodeExternDispatchStandalone(uint16 opcode, uint16 operandVal) external pure {
        bytes32 raw = bytes32(uint256(opcode)) << 0x10 | bytes32(uint256(operandVal));
        (uint256 decodedOpcode, OperandV2 decodedOperand) = LibExtern.decodeExternDispatch(ExternDispatchV2.wrap(raw));
        assertEq(decodedOpcode, uint256(opcode));
        assertEq(OperandV2.unwrap(decodedOperand), bytes32(uint256(operandVal)));
    }

    /// Decode masks the opcode to 16 bits even when high bits are set in the
    /// dispatch word above the opcode region.
    function testDecodeExternDispatchMasksOpcode(bytes32 raw, uint16 operandVal) external pure {
        // Force high bits above the opcode+operand region so they would leak
        // through an unmasked shift.
        raw = raw | bytes32(uint256(1) << 32);
        // Preserve only the operand in the low 16 bits.
        raw = (raw & ~bytes32(uint256(type(uint16).max))) | bytes32(uint256(operandVal));
        (uint256 decodedOpcode,) = LibExtern.decodeExternDispatch(ExternDispatchV2.wrap(raw));
        assertLe(decodedOpcode, type(uint16).max, "opcode must fit in 16 bits");
    }

    /// Standalone decode of `EncodedExternDispatchV2` from a manually
    /// constructed word, independent of `encodeExternCall`.
    function testDecodeExternCallStandalone(address externAddr, uint16 opcode, uint16 operandVal) external pure {
        bytes32 dispatch = bytes32(uint256(opcode)) << 0x10 | bytes32(uint256(operandVal));
        bytes32 raw = bytes32(uint256(uint160(externAddr))) | dispatch << 160;
        (IInterpreterExternV4 decodedExtern, ExternDispatchV2 decodedDispatch) =
            LibExtern.decodeExternCall(EncodedExternDispatchV2.wrap(raw));
        assertEq(address(decodedExtern), externAddr);
        assertEq(ExternDispatchV2.unwrap(decodedDispatch), dispatch);
    }
}
