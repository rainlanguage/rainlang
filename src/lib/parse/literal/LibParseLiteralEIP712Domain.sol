// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ParseState} from "../LibParseState.sol";
import {LibParseError} from "../LibParseError.sol";
import {LibParseLiteralHex} from "./LibParseLiteralHex.sol";
import {LibParseLiteralDecimal} from "./LibParseLiteralDecimal.sol";
import {Float, LibDecimalFloat} from "rain-math-float-0.3.11/src/lib/LibDecimalFloat.sol";
import {
    UnknownEIP712DomainField,
    EIP712DomainFieldOutOfOrder,
    MalformedEIP712DomainValue,
    EIP712DomainNoFields
} from "../../../error/ErrParse.sol";
import {
    CMASK_WHITESPACE,
    CMASK_PRINTABLE,
    CMASK_NUMERIC_0_9,
    CMASK_STRING_LITERAL_HEAD,
    CMASK_STRING_LITERAL_TAIL,
    CMASK_STRING_LITERAL_END,
    CMASK_LITERAL_HEX_DISPATCH
} from "rain-string-0.3.9/src/lib/parse/LibParseCMask.sol";
import {LibParseChar} from "rain-string-0.3.9/src/lib/parse/LibParseChar.sol";

bytes constant EIP712_DOMAIN_SEPARATOR_DISPATCH = "eip712-domain-separator";

bytes constant EIP712_DOMAIN_KEYWORD_NAME = "name";
bytes constant EIP712_DOMAIN_KEYWORD_VERSION = "version";
bytes constant EIP712_DOMAIN_KEYWORD_CHAIN_ID = "chain-id";
bytes constant EIP712_DOMAIN_KEYWORD_VERIFYING_CONTRACT = "verifying-contract";
bytes constant EIP712_DOMAIN_KEYWORD_SALT = "salt";

bytes constant EIP712_DOMAIN_CHAIN_ID_CURRENT = "current";

bytes constant EIP712_DOMAIN_TYPE_PREFIX = "EIP712Domain(";
bytes constant EIP712_DOMAIN_TYPE_SUFFIX = ")";
bytes constant EIP712_DOMAIN_TYPE_MEMBER_SEPARATOR = ",";

bytes constant EIP712_DOMAIN_MEMBER_NAME = "string name";
bytes constant EIP712_DOMAIN_MEMBER_VERSION = "string version";
bytes constant EIP712_DOMAIN_MEMBER_CHAIN_ID = "uint256 chainId";
bytes constant EIP712_DOMAIN_MEMBER_VERIFYING_CONTRACT = "address verifyingContract";
bytes constant EIP712_DOMAIN_MEMBER_SALT = "bytes32 salt";

bytes constant EIP712_DOMAIN_SPRITE =
    "eip712-domain-separatorchain-idverifying-contractcurrentEIP712Domain(string namestring versionuint256 chainIdaddress verifyingContractbytes32 salt,)";

/// @dev Sprite entries: `(offset << 8) | length`.
uint256 constant EIP712_DOMAIN_SPRITE_DISPATCH = 23;
uint256 constant EIP712_DOMAIN_SPRITE_KEYWORD_CHAIN_ID = (23 << 8) | 8;
uint256 constant EIP712_DOMAIN_SPRITE_KEYWORD_VERIFYING_CONTRACT = (31 << 8) | 18;
uint256 constant EIP712_DOMAIN_SPRITE_CHAIN_ID_CURRENT = (49 << 8) | 7;
uint256 constant EIP712_DOMAIN_SPRITE_TYPE_PREFIX = (56 << 8) | 13;
uint256 constant EIP712_DOMAIN_SPRITE_MEMBER_NAME = (69 << 8) | 11;
uint256 constant EIP712_DOMAIN_SPRITE_KEYWORD_NAME = (76 << 8) | 4;
uint256 constant EIP712_DOMAIN_SPRITE_MEMBER_VERSION = (80 << 8) | 14;
uint256 constant EIP712_DOMAIN_SPRITE_KEYWORD_VERSION = (87 << 8) | 7;
uint256 constant EIP712_DOMAIN_SPRITE_MEMBER_CHAIN_ID = (94 << 8) | 15;
uint256 constant EIP712_DOMAIN_SPRITE_MEMBER_VERIFYING_CONTRACT = (109 << 8) | 25;
uint256 constant EIP712_DOMAIN_SPRITE_MEMBER_SALT = (134 << 8) | 12;
uint256 constant EIP712_DOMAIN_SPRITE_KEYWORD_SALT = (142 << 8) | 4;
uint256 constant EIP712_DOMAIN_SPRITE_TYPE_MEMBER_SEPARATOR = (146 << 8) | 1;
uint256 constant EIP712_DOMAIN_SPRITE_TYPE_SUFFIX = (147 << 8) | 1;

/// @dev Longest type string (95 bytes) plus a word of `copySprite` overrun.
uint256 constant EIP712_DOMAIN_TYPE_BUFFER_LENGTH = 0x80;
/// @dev The type hash and the five encoded field values.
uint256 constant EIP712_DOMAIN_ENCODED_BUFFER_LENGTH = 0xC0;

uint256 constant EIP712_DOMAIN_VERIFYING_CONTRACT_HEX_DIGITS = 0x28;
uint256 constant EIP712_DOMAIN_SALT_HEX_DIGITS = 0x40;

/// @dev A field keyword or the `current` chain id: printable ASCII except
/// whitespace.
uint256 constant CMASK_EIP712_DOMAIN_TOKEN = CMASK_PRINTABLE & ~CMASK_WHITESPACE;

uint256 constant EIP712_DOMAIN_FIELD_NAME = 0;
uint256 constant EIP712_DOMAIN_FIELD_VERSION = 1;
uint256 constant EIP712_DOMAIN_FIELD_CHAIN_ID = 2;
uint256 constant EIP712_DOMAIN_FIELD_VERIFYING_CONTRACT = 3;
uint256 constant EIP712_DOMAIN_FIELD_SALT = 4;
uint256 constant EIP712_DOMAIN_FIELD_UNKNOWN = 5;

/// @title LibParseLiteralEIP712Domain
/// @notice Native `[eip712-domain-separator ...]` literal: the EIP-712 domain
/// separator of the listed `EIP712Domain` fields, computed at parse time.
/// The body is whitespace separated field keywords, each followed by its
/// value, in canonical `EIP712Domain` order, each field at most once, any
/// non-empty subset, e.g.
/// `[eip712-domain-separator name "prices" version "1" chain-id 1]`:
/// - `name "..."`, `version "..."`: the keccak256 of a Rainlang string
///   literal's contents.
/// - `chain-id current`: the parsing chain's `block.chainid`.
/// - `chain-id <decimal>`: a Rainlang decimal literal that is a non-negative
///   integer.
/// - `verifying-contract 0x` and exactly 40 hex digits.
/// - `salt 0x` and exactly 64 hex digits.
library LibParseLiteralEIP712Domain {
    using LibParseError for ParseState;
    using LibParseLiteralHex for ParseState;

    /// @notice Whether the dispatch region is `eip712-domain-separator`.
    /// @param dispatchStart The start of the dispatch.
    /// @param dispatchEnd The end of the dispatch.
    /// @return True if the dispatch matches.
    function isDispatch(uint256 dispatchStart, uint256 dispatchEnd) internal pure returns (bool) {
        return regionEqualsSprite(EIP712_DOMAIN_SPRITE, dispatchStart, dispatchEnd, EIP712_DOMAIN_SPRITE_DISPATCH);
    }

    /// @notice Computes the domain separator from a literal body.
    /// @param state The current parse state.
    /// @param cursor The start of the body.
    /// @param end The end of the body.
    /// @return The EIP-712 domain separator.
    function parseDomainSeparator(ParseState memory state, uint256 cursor, uint256 end)
        internal
        view
        returns (bytes32)
    {
        bytes memory sprite = EIP712_DOMAIN_SPRITE;
        uint256 typeStart;
        uint256 encodedStart;
        assembly ("memory-safe") {
            typeStart := mload(0x40)
            encodedStart := add(typeStart, EIP712_DOMAIN_TYPE_BUFFER_LENGTH)
            mstore(0x40, add(encodedStart, EIP712_DOMAIN_ENCODED_BUFFER_LENGTH))
        }
        uint256 typeCursor = copySprite(sprite, typeStart, EIP712_DOMAIN_SPRITE_TYPE_PREFIX);
        uint256 encodedCursor = encodedStart + 0x20;
        uint256 nextField = 0;
        cursor = LibParseChar.skipMask(cursor, end, CMASK_WHITESPACE);
        if (cursor >= end) {
            revert EIP712DomainNoFields(state.parseErrorOffset(cursor));
        }
        while (cursor < end) {
            uint256 fieldStart = cursor;
            cursor = LibParseChar.skipMask(cursor, end, CMASK_EIP712_DOMAIN_TOKEN);
            uint256 field = fieldIndex(sprite, fieldStart, cursor);
            if (field == EIP712_DOMAIN_FIELD_UNKNOWN) {
                revert UnknownEIP712DomainField(state.parseErrorOffset(fieldStart));
            }
            if (field < nextField) {
                revert EIP712DomainFieldOutOfOrder(state.parseErrorOffset(fieldStart));
            }
            nextField = field + 1;
            cursor = LibParseChar.skipMask(cursor, end, CMASK_WHITESPACE);
            if (cursor >= end) {
                revert MalformedEIP712DomainValue(state.parseErrorOffset(cursor));
            }
            (uint256 valueEnd, bytes32 value) = parseValue(state, field, cursor, end);
            cursor = LibParseChar.skipMask(valueEnd, end, CMASK_WHITESPACE);
            if (cursor == valueEnd && cursor < end) {
                revert MalformedEIP712DomainValue(state.parseErrorOffset(cursor));
            }

            if (encodedCursor > encodedStart + 0x20) {
                typeCursor = copySprite(sprite, typeCursor, EIP712_DOMAIN_SPRITE_TYPE_MEMBER_SEPARATOR);
            }
            typeCursor = copySprite(sprite, typeCursor, fieldType(field));
            assembly ("memory-safe") {
                mstore(encodedCursor, value)
            }
            encodedCursor += 0x20;
        }
        typeCursor = copySprite(sprite, typeCursor, EIP712_DOMAIN_SPRITE_TYPE_SUFFIX);
        bytes32 domainSeparator;
        assembly ("memory-safe") {
            mstore(encodedStart, keccak256(typeStart, sub(typeCursor, typeStart)))
            domainSeparator := keccak256(encodedStart, sub(encodedCursor, encodedStart))
        }
        return domainSeparator;
    }

    /// @notice Parses one field value as its 32 byte ABI encoding.
    /// @param state The current parse state.
    /// @param field The field index.
    /// @param cursor The start of the value, before `end`.
    /// @param end The end of the body.
    /// @return The cursor after the value.
    /// @return The encoded value.
    function parseValue(ParseState memory state, uint256 field, uint256 cursor, uint256 end)
        internal
        view
        returns (uint256, bytes32)
    {
        if (field == EIP712_DOMAIN_FIELD_NAME || field == EIP712_DOMAIN_FIELD_VERSION) {
            return parseStringHash(state, cursor, end);
        }
        if (field == EIP712_DOMAIN_FIELD_CHAIN_ID) {
            return parseChainId(state, cursor, end);
        }
        if (field == EIP712_DOMAIN_FIELD_SALT) {
            return parseFixedHex(state, cursor, end, EIP712_DOMAIN_SALT_HEX_DIGITS);
        }
        return parseFixedHex(state, cursor, end, EIP712_DOMAIN_VERIFYING_CONTRACT_HEX_DIGITS);
    }

    /// @notice Parses a `"..."` string literal value as the keccak256 of its
    /// contents.
    /// @param state The current parse state.
    /// @param cursor The start of the value, at a non-whitespace char.
    /// @param end The end of the body.
    /// @return The cursor after the closing quote.
    /// @return The hash of the string contents.
    function parseStringHash(ParseState memory state, uint256 cursor, uint256 end)
        internal
        pure
        returns (uint256, bytes32)
    {
        if (LibParseChar.isMask(cursor, end, CMASK_STRING_LITERAL_HEAD) == 0) {
            revert MalformedEIP712DomainValue(state.parseErrorOffset(cursor));
        }
        uint256 innerStart = cursor + 1;
        uint256 innerEnd = LibParseChar.skipMask(innerStart, end, CMASK_STRING_LITERAL_TAIL);
        if (LibParseChar.isMask(innerEnd, end, CMASK_STRING_LITERAL_END) == 0) {
            revert MalformedEIP712DomainValue(state.parseErrorOffset(innerEnd));
        }
        bytes32 stringHash;
        assembly ("memory-safe") {
            stringHash := keccak256(innerStart, sub(innerEnd, innerStart))
        }
        return (innerEnd + 1, stringHash);
    }

    /// @notice Parses `current` as the parsing chain's `block.chainid`, or a
    /// decimal literal value that is a non-negative integer.
    /// @param state The current parse state.
    /// @param cursor The start of the value, at a non-whitespace char.
    /// @param end The end of the body.
    /// @return The cursor after the value.
    /// @return The chain id.
    function parseChainId(ParseState memory state, uint256 cursor, uint256 end)
        internal
        view
        returns (uint256, bytes32)
    {
        if (LibParseChar.isMask(cursor, end, CMASK_NUMERIC_0_9) == 0) {
            uint256 tokenEnd = LibParseChar.skipMask(cursor, end, CMASK_EIP712_DOMAIN_TOKEN);
            if (!regionEqualsSprite(EIP712_DOMAIN_SPRITE, cursor, tokenEnd, EIP712_DOMAIN_SPRITE_CHAIN_ID_CURRENT)) {
                revert MalformedEIP712DomainValue(state.parseErrorOffset(cursor));
            }
            return (tokenEnd, bytes32(block.chainid));
        }
        (uint256 valueEnd, bytes32 packed) = LibParseLiteralDecimal.parseDecimalFloatPacked(state, cursor, end);
        (uint256 chainId, bool lossless) = LibDecimalFloat.toFixedDecimalLossy(Float.wrap(packed), 0);
        if (!lossless) {
            revert MalformedEIP712DomainValue(state.parseErrorOffset(cursor));
        }
        return (valueEnd, bytes32(chainId));
    }

    /// @notice Parses `0x` and exactly `digits` hex digits.
    /// @param state The current parse state.
    /// @param cursor The start of the value.
    /// @param end The end of the body.
    /// @param digits The required number of hex digits.
    /// @return The cursor after the hex digits.
    /// @return The value, right aligned.
    function parseFixedHex(ParseState memory state, uint256 cursor, uint256 end, uint256 digits)
        internal
        pure
        returns (uint256, bytes32)
    {
        uint256 head;
        uint256 disambiguate;
        assembly ("memory-safe") {
            let word := mload(cursor)
            //slither-disable-next-line incorrect-shift
            head := shl(byte(0, word), 1)
            //slither-disable-next-line incorrect-shift
            disambiguate := shl(byte(1, word), 1)
        }
        bool hexDispatch = (head & CMASK_NUMERIC_0_9) != 0 && (head | disambiguate) == CMASK_LITERAL_HEX_DISPATCH;
        if (cursor + 1 >= end || !hexDispatch) {
            revert MalformedEIP712DomainValue(state.parseErrorOffset(cursor));
        }
        //slither-disable-next-line unused-return
        (uint256 hexStart, uint256 hexEnd,) = state.boundHex(cursor, end);
        if (hexEnd - hexStart != digits) {
            revert MalformedEIP712DomainValue(state.parseErrorOffset(cursor));
        }
        (uint256 valueEnd, bytes32 value) = state.parseHex(cursor, end);
        return (valueEnd, value);
    }

    /// @notice Maps a field keyword region to its canonical index.
    /// @param sprite `EIP712_DOMAIN_SPRITE` in memory.
    /// @param start The start of the field keyword.
    /// @param end The end of the field keyword.
    /// @return The field index, or `EIP712_DOMAIN_FIELD_UNKNOWN`.
    function fieldIndex(bytes memory sprite, uint256 start, uint256 end) internal pure returns (uint256) {
        if (regionEqualsSprite(sprite, start, end, EIP712_DOMAIN_SPRITE_KEYWORD_NAME)) {
            return EIP712_DOMAIN_FIELD_NAME;
        }
        if (regionEqualsSprite(sprite, start, end, EIP712_DOMAIN_SPRITE_KEYWORD_VERSION)) {
            return EIP712_DOMAIN_FIELD_VERSION;
        }
        if (regionEqualsSprite(sprite, start, end, EIP712_DOMAIN_SPRITE_KEYWORD_CHAIN_ID)) {
            return EIP712_DOMAIN_FIELD_CHAIN_ID;
        }
        if (regionEqualsSprite(sprite, start, end, EIP712_DOMAIN_SPRITE_KEYWORD_VERIFYING_CONTRACT)) {
            return EIP712_DOMAIN_FIELD_VERIFYING_CONTRACT;
        }
        if (regionEqualsSprite(sprite, start, end, EIP712_DOMAIN_SPRITE_KEYWORD_SALT)) {
            return EIP712_DOMAIN_FIELD_SALT;
        }
        return EIP712_DOMAIN_FIELD_UNKNOWN;
    }

    /// @notice The sprite entry of the `EIP712Domain` type string member for a
    /// field index.
    /// @param field A known field index.
    /// @return The sprite entry of the member, e.g. `string name`.
    function fieldType(uint256 field) internal pure returns (uint256) {
        if (field == EIP712_DOMAIN_FIELD_NAME) {
            return EIP712_DOMAIN_SPRITE_MEMBER_NAME;
        }
        if (field == EIP712_DOMAIN_FIELD_VERSION) {
            return EIP712_DOMAIN_SPRITE_MEMBER_VERSION;
        }
        if (field == EIP712_DOMAIN_FIELD_CHAIN_ID) {
            return EIP712_DOMAIN_SPRITE_MEMBER_CHAIN_ID;
        }
        if (field == EIP712_DOMAIN_FIELD_VERIFYING_CONTRACT) {
            return EIP712_DOMAIN_SPRITE_MEMBER_VERIFYING_CONTRACT;
        }
        return EIP712_DOMAIN_SPRITE_MEMBER_SALT;
    }

    /// @notice Copies a sprite entry to `cursor`. Writes a full word, so up to
    /// 31 bytes past the entry are overwritten.
    /// @param sprite `EIP712_DOMAIN_SPRITE` in memory.
    /// @param cursor Where to copy the entry.
    /// @param entry The sprite entry, `(offset << 8) | length`.
    /// @return The cursor after the copied entry.
    function copySprite(bytes memory sprite, uint256 cursor, uint256 entry) internal pure returns (uint256) {
        assembly ("memory-safe") {
            mstore(cursor, mload(add(add(sprite, 0x20), shr(8, entry))))
            cursor := add(cursor, and(entry, 0xFF))
        }
        return cursor;
    }

    /// @notice Whether the memory region `[start, end)` equals a sprite entry.
    /// @param sprite `EIP712_DOMAIN_SPRITE` in memory.
    /// @param start The start of the region.
    /// @param end The end of the region.
    /// @param entry The sprite entry, `(offset << 8) | length`.
    /// @return True if equal.
    function regionEqualsSprite(bytes memory sprite, uint256 start, uint256 end, uint256 entry)
        internal
        pure
        returns (bool)
    {
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
