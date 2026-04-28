// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {NotAnExternContract} from "rain.interpreter.interface/error/ErrExtern.sol";

/// @dev Workaround for https://github.com/foundry-rs/foundry/issues/6572
contract ErrExtern {}

/// @notice Thrown when an extern opcode is out of range of the available function
/// pointers.
/// @param opcode The opcode that was dispatched.
/// @param fsCount The number of available function pointers.
error ExternOpcodeOutOfRange(uint256 opcode, uint256 fsCount);

/// @notice Thrown at construction when the opcode and integrity function pointer
/// tables have different lengths.
/// @param opcodeCount The number of opcode function pointers.
/// @param integrityCount The number of integrity function pointers.
error ExternPointersMismatch(uint256 opcodeCount, uint256 integrityCount);

/// @notice Thrown when the outputs length is not equal to the expected length.
/// @param expectedLength The number of outputs the caller expected.
/// @param actualLength The number of outputs actually returned.
error BadOutputsLength(uint256 expectedLength, uint256 actualLength);

/// @notice Thrown when an extern contract's integrity check returns a
/// different number of inputs than the operand specifies.
/// @param expected The number of inputs encoded in the operand.
/// @param actual The number of inputs returned by externIntegrity.
error ExternIntegrityInputsMismatch(uint256 expected, uint256 actual);

/// @notice Thrown when an extern contract's integrity check returns a
/// different number of outputs than the operand specifies.
/// @param expected The number of outputs encoded in the operand.
/// @param actual The number of outputs returned by externIntegrity.
error ExternIntegrityOutputsMismatch(uint256 expected, uint256 actual);

/// @notice Thrown at construction when there are no opcode function pointers.
error ExternOpcodePointersEmpty();
