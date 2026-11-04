// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Pointer} from "rain-solmem-0.1.28/src/lib/LibPointer.sol";
import {LibCtPop} from "rain-math-binary-0.1.4/src/lib/LibCtPop.sol";
import {OperandV2, StackItem} from "../../../interface/IInterpreterV4.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {EIP712DomainFieldsInvalid} from "../../../error/ErrIntegrity.sol";

/// @dev Operand bits selecting each EIP-712 domain field, in canonical order.
uint256 constant EIP712_DOMAIN_FIELD_NAME = 1;
uint256 constant EIP712_DOMAIN_FIELD_VERSION = 1 << 1;
uint256 constant EIP712_DOMAIN_FIELD_CHAIN_ID = 1 << 2;
uint256 constant EIP712_DOMAIN_FIELD_VERIFYING_CONTRACT = 1 << 3;
uint256 constant EIP712_DOMAIN_FIELD_SALT = 1 << 4;
uint256 constant EIP712_DOMAIN_FIELDS_ALL = 0x1F;

/// @title LibOpEIP712DomainSeparator
/// @notice `eip712-domain-separator`: the EIP-712 domain separator over the
/// domain fields selected by the operand.
///
/// The low 16 bits of the operand are a bitmask over `name`, `version`,
/// `chainId`, `verifyingContract`, `salt` (bit 0 to bit 4). The inputs are the
/// selected fields in that order, each as the 32 byte word `abi.encode` gives
/// it; `name` and `version` are their keccak256 hashes. The output is
/// `keccak256(abi.encode(typehash, field...))` where `typehash` is the hash of
/// the `EIP712Domain(...)` type string for exactly the selected fields.
library LibOpEIP712DomainSeparator {
    /// @notice `eip712-domain-separator` integrity check. One input per
    /// selected field, produces 1 output. Reverts if no field is selected or a
    /// bit outside the five fields is set.
    /// @param operand Low 16 bits are the field bitmask.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2 operand) internal pure returns (uint256, uint256) {
        uint256 fields = uint256(OperandV2.unwrap(operand)) & 0xFFFF;
        if (fields == 0 || fields > EIP712_DOMAIN_FIELDS_ALL) {
            revert EIP712DomainFieldsInvalid(fields);
        }
        return (LibCtPop.ctpop(fields), 1);
    }

    /// @notice The keccak256 of the `EIP712Domain(...)` type string for the
    /// selected fields.
    /// @param fields The field bitmask.
    /// @return The type hash.
    function domainTypeHash(uint256 fields) internal pure returns (bytes32) {
        bytes memory members = "";
        bytes memory separator = "";
        if (fields & EIP712_DOMAIN_FIELD_NAME != 0) {
            members = bytes.concat(members, separator, "string name");
            separator = ",";
        }
        if (fields & EIP712_DOMAIN_FIELD_VERSION != 0) {
            members = bytes.concat(members, separator, "string version");
            separator = ",";
        }
        if (fields & EIP712_DOMAIN_FIELD_CHAIN_ID != 0) {
            members = bytes.concat(members, separator, "uint256 chainId");
            separator = ",";
        }
        if (fields & EIP712_DOMAIN_FIELD_VERIFYING_CONTRACT != 0) {
            members = bytes.concat(members, separator, "address verifyingContract");
            separator = ",";
        }
        if (fields & EIP712_DOMAIN_FIELD_SALT != 0) {
            members = bytes.concat(members, separator, "bytes32 salt");
        }
        return keccak256(bytes.concat("EIP712Domain(", members, ")"));
    }

    /// @notice `eip712-domain-separator` opcode.
    /// @param operand Low 16 bits are the field bitmask, low 4 bits of the
    /// high byte are the input count.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2 operand, Pointer stackTop) internal pure returns (Pointer) {
        bytes32 typeHash = domainTypeHash(uint256(OperandV2.unwrap(operand)) & 0xFFFF);
        uint256 inputs = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;
        assembly ("memory-safe") {
            // Unallocated memory past the free memory pointer is scratch for the encoding.
            let start := mload(0x40)
            mstore(start, typeHash)
            let length := mul(inputs, 0x20)
            mcopy(add(start, 0x20), stackTop, length)
            stackTop := sub(add(stackTop, length), 0x20)
            mstore(stackTop, keccak256(start, add(length, 0x20)))
        }
        return stackTop;
    }

    /// @notice Reference implementation of `eip712-domain-separator` for
    /// testing.
    /// @param operand Low 16 bits are the field bitmask.
    /// @param inputs The input values from the stack.
    /// @return The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2 operand, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory)
    {
        uint256 fields = uint256(OperandV2.unwrap(operand)) & 0xFFFF;
        string memory typeString = "";
        bytes memory encoded = "";
        uint256 cursor = 0;
        for (uint256 bit = 0; bit < 5; bit++) {
            if (fields & (1 << bit) == 0) {
                continue;
            }
            string memory member;
            if (bit == 0) {
                member = "string name";
            } else if (bit == 1) {
                member = "string version";
            } else if (bit == 2) {
                member = "uint256 chainId";
            } else if (bit == 3) {
                member = "address verifyingContract";
            } else {
                member = "bytes32 salt";
            }
            if (bytes(typeString).length > 0) {
                typeString = string.concat(typeString, ",");
            }
            typeString = string.concat(typeString, member);
            encoded = bytes.concat(encoded, StackItem.unwrap(inputs[cursor]));
            cursor++;
        }
        bytes32 typeHash = keccak256(bytes(string.concat("EIP712Domain(", typeString, ")")));
        StackItem[] memory outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(keccak256(bytes.concat(typeHash, encoded)));
        return outputs;
    }
}
