// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @dev Every string the parser matches or copies, back to back.
bytes constant PARSE_SPRITE =
    "eip712-domain-separatorchain-idverifying-contractcurrentEIP712Domain(string namestring versionuint256 chainIdaddress verifyingContractbytes32 salt,)using-words-from";

/// @dev Sprite entries: `(offset << 8) | length`.
uint256 constant PARSE_SPRITE_EIP712_DOMAIN_DISPATCH = 23;
uint256 constant PARSE_SPRITE_EIP712_DOMAIN_KEYWORD_CHAIN_ID = (23 << 8) | 8;
uint256 constant PARSE_SPRITE_EIP712_DOMAIN_KEYWORD_VERIFYING_CONTRACT = (31 << 8) | 18;
uint256 constant PARSE_SPRITE_EIP712_DOMAIN_CHAIN_ID_CURRENT = (49 << 8) | 7;
uint256 constant PARSE_SPRITE_EIP712_DOMAIN_TYPE_PREFIX = (56 << 8) | 13;
uint256 constant PARSE_SPRITE_EIP712_DOMAIN_MEMBER_NAME = (69 << 8) | 11;
uint256 constant PARSE_SPRITE_EIP712_DOMAIN_KEYWORD_NAME = (76 << 8) | 4;
uint256 constant PARSE_SPRITE_EIP712_DOMAIN_MEMBER_VERSION = (80 << 8) | 14;
uint256 constant PARSE_SPRITE_EIP712_DOMAIN_KEYWORD_VERSION = (87 << 8) | 7;
uint256 constant PARSE_SPRITE_EIP712_DOMAIN_MEMBER_CHAIN_ID = (94 << 8) | 15;
uint256 constant PARSE_SPRITE_EIP712_DOMAIN_MEMBER_VERIFYING_CONTRACT = (109 << 8) | 25;
uint256 constant PARSE_SPRITE_EIP712_DOMAIN_MEMBER_SALT = (134 << 8) | 12;
uint256 constant PARSE_SPRITE_EIP712_DOMAIN_KEYWORD_SALT = (142 << 8) | 4;
uint256 constant PARSE_SPRITE_EIP712_DOMAIN_TYPE_MEMBER_SEPARATOR = (146 << 8) | 1;
uint256 constant PARSE_SPRITE_EIP712_DOMAIN_TYPE_SUFFIX = (147 << 8) | 1;
uint256 constant PARSE_SPRITE_PRAGMA_KEYWORD = (148 << 8) | 16;

/// @title LibParseSprite
/// @notice Copies and compares `PARSE_SPRITE` entries in memory.
library LibParseSprite {
    /// @notice Copies a sprite entry to `cursor`. Writes a full word, so up to
    /// 31 bytes past the entry are overwritten.
    /// @param sprite `PARSE_SPRITE` in memory.
    /// @param cursor Where to copy the entry.
    /// @param entry The sprite entry, `(offset << 8) | length`.
    /// @return The cursor after the copied entry.
    function copy(bytes memory sprite, uint256 cursor, uint256 entry) internal pure returns (uint256) {
        assembly ("memory-safe") {
            mstore(cursor, mload(add(add(sprite, 0x20), shr(8, entry))))
            cursor := add(cursor, and(entry, 0xFF))
        }
        return cursor;
    }

    /// @notice Whether the memory region `[start, end)` equals a sprite entry.
    /// @param sprite `PARSE_SPRITE` in memory.
    /// @param start The start of the region.
    /// @param end The end of the region.
    /// @param entry The sprite entry, `(offset << 8) | length`.
    /// @return True if equal.
    function regionEquals(bytes memory sprite, uint256 start, uint256 end, uint256 entry) internal pure returns (bool) {
        uint256 length = entry & 0xFF;
        if (end - start != length) {
            return false;
        }
        bool equal;
        assembly ("memory-safe") {
            equal := eq(keccak256(start, length), keccak256(add(add(sprite, 0x20), shr(8, entry)), length))
        }
        return equal;
    }
}
