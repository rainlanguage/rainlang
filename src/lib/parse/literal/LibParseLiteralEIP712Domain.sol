// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ParseState} from "../LibParseState.sol";
import {LibParseError} from "../LibParseError.sol";
import {LibParseLiteralHex} from "./LibParseLiteralHex.sol";
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
    CMASK_STRING_LITERAL_END
} from "rain-string-0.3.9/src/lib/parse/LibParseCMask.sol";
import {LibParseChar} from "rain-string-0.3.9/src/lib/parse/LibParseChar.sol";

bytes constant EIP712_DOMAIN_SEPARATOR_DISPATCH = "eip712-domain-separator";

/// @dev A field keyword or unquoted value: printable ASCII except whitespace.
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
/// non-empty subset, e.g. `[eip712-domain-separator name prices version 1]`:
/// - `name <value>`, `version <value>`: the keccak256 of the value, which is
///   `"..."` quoted when it contains whitespace.
/// - `chainId <decimal>`, or bare `chainId` for the parsing chain's
///   `block.chainid` when the next token does not start with a digit.
/// - `verifyingContract 0x` and exactly 40 hex digits.
/// - `salt 0x` and exactly 64 hex digits.
/// After every field but `chainId` the next token is its value, even if it is
/// a field keyword.
library LibParseLiteralEIP712Domain {
    using LibParseError for ParseState;
    using LibParseLiteralHex for ParseState;

    /// @notice Whether the dispatch region is `eip712-domain-separator`.
    /// @param dispatchStart The start of the dispatch.
    /// @param dispatchEnd The end of the dispatch.
    /// @return True if the dispatch matches.
    function isDispatch(uint256 dispatchStart, uint256 dispatchEnd) internal pure returns (bool) {
        return regionEquals(dispatchStart, dispatchEnd, EIP712_DOMAIN_SEPARATOR_DISPATCH);
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
        bytes memory typeString = "";
        bytes memory encoded = "";
        uint256 nextField = 0;
        cursor = LibParseChar.skipMask(cursor, end, CMASK_WHITESPACE);
        if (cursor >= end) {
            revert EIP712DomainNoFields(state.parseErrorOffset(cursor));
        }
        while (cursor < end) {
            uint256 fieldStart = cursor;
            cursor = LibParseChar.skipMask(cursor, end, CMASK_EIP712_DOMAIN_TOKEN);
            uint256 field = fieldIndex(fieldStart, cursor);
            if (field == EIP712_DOMAIN_FIELD_UNKNOWN) {
                revert UnknownEIP712DomainField(state.parseErrorOffset(fieldStart));
            }
            if (field < nextField) {
                revert EIP712DomainFieldOutOfOrder(state.parseErrorOffset(fieldStart));
            }
            nextField = field + 1;
            cursor = LibParseChar.skipMask(cursor, end, CMASK_WHITESPACE);

            bytes32 value;
            if (field == EIP712_DOMAIN_FIELD_CHAIN_ID && LibParseChar.isMask(cursor, end, CMASK_NUMERIC_0_9) == 0) {
                value = bytes32(block.chainid);
            } else {
                if (cursor >= end) {
                    revert MalformedEIP712DomainValue(state.parseErrorOffset(cursor));
                }
                (cursor, value) = parseValue(state, field, cursor, end);
                uint256 valueEnd = cursor;
                cursor = LibParseChar.skipMask(cursor, end, CMASK_WHITESPACE);
                if (cursor == valueEnd && cursor < end) {
                    revert MalformedEIP712DomainValue(state.parseErrorOffset(cursor));
                }
            }

            if (typeString.length > 0) {
                typeString = bytes.concat(typeString, ",");
            }
            typeString = bytes.concat(typeString, fieldType(field));
            encoded = bytes.concat(encoded, value);
        }
        return keccak256(bytes.concat(keccak256(bytes.concat("EIP712Domain(", typeString, ")")), encoded));
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
        pure
        returns (uint256, bytes32)
    {
        if (field == EIP712_DOMAIN_FIELD_NAME || field == EIP712_DOMAIN_FIELD_VERSION) {
            return parseStringHash(state, cursor, end);
        }
        if (field == EIP712_DOMAIN_FIELD_CHAIN_ID) {
            return parseDecimal(state, cursor, end);
        }
        return parseFixedHex(state, cursor, end, field == EIP712_DOMAIN_FIELD_SALT ? uint256(0x40) : uint256(0x28));
    }

    /// @notice Parses a string value as the keccak256 of its contents: the
    /// bytes between `"` quotes if it starts with `"`, else the token.
    /// @param state The current parse state.
    /// @param cursor The start of the value, at a non-whitespace char.
    /// @param end The end of the body.
    /// @return The cursor after the value.
    /// @return The hash of the string contents.
    function parseStringHash(ParseState memory state, uint256 cursor, uint256 end)
        internal
        pure
        returns (uint256, bytes32)
    {
        uint256 innerStart = cursor;
        uint256 innerEnd;
        uint256 valueEnd;
        if (LibParseChar.isMask(cursor, end, CMASK_STRING_LITERAL_HEAD) != 0) {
            innerStart = cursor + 1;
            innerEnd = LibParseChar.skipMask(innerStart, end, CMASK_STRING_LITERAL_TAIL | CMASK_WHITESPACE);
            if (LibParseChar.isMask(innerEnd, end, CMASK_STRING_LITERAL_END) == 0) {
                revert MalformedEIP712DomainValue(state.parseErrorOffset(innerEnd));
            }
            valueEnd = innerEnd + 1;
        } else {
            innerEnd = LibParseChar.skipMask(cursor, end, CMASK_EIP712_DOMAIN_TOKEN);
            valueEnd = innerEnd;
        }
        bytes32 stringHash;
        assembly ("memory-safe") {
            stringHash := keccak256(innerStart, sub(innerEnd, innerStart))
        }
        return (valueEnd, stringHash);
    }

    /// @notice Parses an unsigned decimal integer.
    /// @param state The current parse state.
    /// @param cursor The start of the value, at a digit.
    /// @param end The end of the body.
    /// @return The cursor after the digits.
    /// @return The integer.
    function parseDecimal(ParseState memory state, uint256 cursor, uint256 end)
        internal
        pure
        returns (uint256, bytes32)
    {
        uint256 start = cursor;
        uint256 value = 0;
        while (cursor < end) {
            uint256 charByte = charAt(cursor);
            //slither-disable-next-line incorrect-shift
            //forge-lint: disable-next-line(incorrect-shift)
            if (((uint256(1) << charByte) & CMASK_NUMERIC_0_9) == 0) {
                break;
            }
            //forge-lint: disable-next-line(unsafe-typecast)
            uint256 digit = charByte - uint256(uint8(bytes1("0")));
            if (value > (type(uint256).max - digit) / 10) {
                revert MalformedEIP712DomainValue(state.parseErrorOffset(start));
            }
            value = value * 10 + digit;
            ++cursor;
        }
        return (cursor, bytes32(value));
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
        uint256 prefix;
        assembly ("memory-safe") {
            prefix := shr(0xf0, mload(cursor))
        }
        //forge-lint: disable-next-line(unsafe-typecast)
        if (cursor + 1 >= end || prefix != uint256(uint16(bytes2("0x")))) {
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
    /// @param start The start of the field keyword.
    /// @param end The end of the field keyword.
    /// @return The field index, or `EIP712_DOMAIN_FIELD_UNKNOWN`.
    function fieldIndex(uint256 start, uint256 end) internal pure returns (uint256) {
        if (regionEquals(start, end, "name")) {
            return EIP712_DOMAIN_FIELD_NAME;
        }
        if (regionEquals(start, end, "version")) {
            return EIP712_DOMAIN_FIELD_VERSION;
        }
        if (regionEquals(start, end, "chainId")) {
            return EIP712_DOMAIN_FIELD_CHAIN_ID;
        }
        if (regionEquals(start, end, "verifyingContract")) {
            return EIP712_DOMAIN_FIELD_VERIFYING_CONTRACT;
        }
        if (regionEquals(start, end, "salt")) {
            return EIP712_DOMAIN_FIELD_SALT;
        }
        return EIP712_DOMAIN_FIELD_UNKNOWN;
    }

    /// @notice The `EIP712Domain` type string member for a field index.
    /// @param field A known field index.
    /// @return The member, e.g. `string name`.
    function fieldType(uint256 field) internal pure returns (bytes memory) {
        if (field == EIP712_DOMAIN_FIELD_NAME) {
            return "string name";
        }
        if (field == EIP712_DOMAIN_FIELD_VERSION) {
            return "string version";
        }
        if (field == EIP712_DOMAIN_FIELD_CHAIN_ID) {
            return "uint256 chainId";
        }
        if (field == EIP712_DOMAIN_FIELD_VERIFYING_CONTRACT) {
            return "address verifyingContract";
        }
        return "bytes32 salt";
    }

    /// @notice Whether the memory region `[start, end)` equals `expected`.
    /// @param start The start of the region.
    /// @param end The end of the region.
    /// @param expected The bytes to compare against.
    /// @return True if equal.
    function regionEquals(uint256 start, uint256 end, bytes memory expected) internal pure returns (bool) {
        uint256 length = end - start;
        if (length != expected.length) {
            return false;
        }
        bytes32 regionHash;
        assembly ("memory-safe") {
            regionHash := keccak256(start, length)
        }
        return regionHash == keccak256(expected);
    }

    /// @notice The byte at `cursor`.
    /// @param cursor The memory position.
    /// @return The byte value.
    function charAt(uint256 cursor) internal pure returns (uint256) {
        uint256 charByte;
        assembly ("memory-safe") {
            charByte := byte(0, mload(cursor))
        }
        return charByte;
    }
}
