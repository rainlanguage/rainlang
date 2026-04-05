// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    RainlangExpressionDeployerDeploymentTest
} from "test/abstract/RainlangExpressionDeployerDeploymentTest.sol";
import {LibIntegrityCheck} from "../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {LibAllStandardOps} from "../../../../src/lib/op/LibAllStandardOps.sol";
import {BadOpInputsLength, BadOpOutputsLength} from "rain.interpreter.interface/error/ErrIntegrity.sol";
import {LibBytecode} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";

/// @title LibIntegrityCheckBadOpIOTest
/// @notice Verifies that integrityCheck2 reverts with BadOpInputsLength and
/// BadOpOutputsLength when a surgically corrupted IO byte in the bytecode
/// does not match the integrity function's computed inputs/outputs.
contract LibIntegrityCheckBadOpIOTest is RainlangExpressionDeployerDeploymentTest {
    /// External wrapper so vm.expectRevert works with the library call.
    /// Computes integrity function pointers at runtime so they are valid
    /// for this contract's inlined library code.
    function externalIntegrityCheck(bytes memory bytecode, bytes32[] memory constants)
        external
        view
        returns (bytes memory)
    {
        return LibIntegrityCheck.integrityCheck2(LibAllStandardOps.integrityFunctionPointers(), bytecode, constants);
    }

    /// Parse valid rainlang, surgically corrupt the IO byte to declare wrong
    /// inputs, verify the integrity check reverts with BadOpInputsLength.
    function testBadOpInputsLength() external {
        // Parse a minimal expression: one constant opcode.
        // Constant integrity returns (0 inputs, 1 output), so the parser
        // sets the IO byte to 0x10.
        (bytes memory bytecode, bytes32[] memory constants) = I_PARSER.unsafeParse(bytes("_: 0xdeadbeef;"));

        // Locate the IO byte of the first opcode via LibBytecode.
        // Source header is 4 bytes (opsCount, stackAlloc, inputs, outputs),
        // then each opcode is 4 bytes: opcodeIndex(1) + ioByte(1) + operand(2).
        Pointer sourcePtr = LibBytecode.sourcePointer(bytecode, 0);
        uint256 ioByteAddr = Pointer.unwrap(sourcePtr) + 5;

        // Corrupt: change inputs from 0 to 1 (0x10 -> 0x11).
        assembly ("memory-safe") {
            mstore8(ioByteAddr, 0x11)
        }

        // Integrity function says 0 inputs, bytecode now says 1.
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 0, 0, 1));
        this.externalIntegrityCheck(bytecode, constants);
    }

    /// Parse valid rainlang, surgically corrupt the IO byte to declare wrong
    /// outputs, verify the integrity check reverts with BadOpOutputsLength.
    function testBadOpOutputsLength() external {
        (bytes memory bytecode, bytes32[] memory constants) = I_PARSER.unsafeParse(bytes("_: 0xdeadbeef;"));

        Pointer sourcePtr = LibBytecode.sourcePointer(bytecode, 0);
        uint256 ioByteAddr = Pointer.unwrap(sourcePtr) + 5;

        // Corrupt: change outputs from 1 to 0, keep inputs at 0 (0x10 -> 0x00).
        // Inputs still match so BadOpInputsLength is not triggered.
        assembly ("memory-safe") {
            mstore8(ioByteAddr, 0x00)
        }

        // Integrity function says 1 output, bytecode now says 0.
        vm.expectRevert(abi.encodeWithSelector(BadOpOutputsLength.selector, 0, 1, 0));
        this.externalIntegrityCheck(bytecode, constants);
    }
}
