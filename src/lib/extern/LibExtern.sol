// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {
    IInterpreterExternV4,
    ExternDispatchV2,
    EncodedExternDispatchV2
} from "rain.interpreter.interface/interface/IInterpreterExternV4.sol";
// StackItem exported for convenience.
//forge-lint: disable-next-line(unused-import)
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

/// @title LibExtern
/// @notice Defines and implements an encoding and decoding scheme for the data that
/// controls the behaviour of externs.
library LibExtern {
    /// @notice Converts an opcode and operand pair into a single 32-byte word.
    /// The encoding scheme is:
    /// - bits [0,16): the operand
    /// - bits [16,32): the opcode
    /// IMPORTANT: The encoding process does not check that either the opcode or
    /// operand fit within 16 bits. This is the responsibility of the caller.
    /// @param opcode The opcode index.
    /// @param operand The operand value.
    /// @return The encoded extern dispatch.
    function encodeExternDispatch(uint256 opcode, OperandV2 operand) internal pure returns (ExternDispatchV2) {
        return ExternDispatchV2.wrap(bytes32(opcode) << 0x10 | OperandV2.unwrap(operand));
    }

    /// @notice Inverse of `encodeExternDispatch`.
    /// @param dispatch The encoded extern dispatch to decode.
    /// @return The opcode index.
    /// @return The operand value.
    function decodeExternDispatch(ExternDispatchV2 dispatch) internal pure returns (uint256, OperandV2) {
        return (
            uint256((ExternDispatchV2.unwrap(dispatch) >> 0x10) & bytes32(uint256(type(uint16).max))),
            OperandV2.wrap(ExternDispatchV2.unwrap(dispatch) & bytes32(uint256(type(uint16).max)))
        );
    }

    /// @notice Encodes an extern address and dispatch pair into a single 32-byte word.
    /// This is the full data required to actually call an extern contract.
    /// The encoding scheme is:
    /// - bits [0,160): the address of the extern contract
    /// - bits [160,176): the dispatch operand
    /// - bits [176,192): the dispatch opcode
    /// Note that the high bits are implied by a correctly encoded
    /// `ExternDispatch`. Use `encodeExternDispatch` to ensure this.
    /// IMPORTANT: The encoding process does not check that any of the values
    /// fit within their respective bit ranges. This is the responsibility of
    /// the caller.
    /// @param extern The extern contract address.
    /// @param dispatch The encoded extern dispatch.
    /// @return The encoded extern call.
    function encodeExternCall(IInterpreterExternV4 extern, ExternDispatchV2 dispatch)
        internal
        pure
        returns (EncodedExternDispatchV2)
    {
        return EncodedExternDispatchV2.wrap(
            bytes32(uint256(uint160(address(extern)))) | ExternDispatchV2.unwrap(dispatch) << 160
        );
    }

    /// @notice Inverse of `encodeExternCall`.
    /// @param dispatch The encoded extern call to decode.
    /// @return The extern contract.
    /// @return The extern dispatch.
    function decodeExternCall(EncodedExternDispatchV2 dispatch)
        internal
        pure
        returns (IInterpreterExternV4, ExternDispatchV2)
    {
        return (
            IInterpreterExternV4(address(uint160(uint256(EncodedExternDispatchV2.unwrap(dispatch))))),
            ExternDispatchV2.wrap(EncodedExternDispatchV2.unwrap(dispatch) >> 160)
        );
    }
}
