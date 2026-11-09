// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {
    PARSE_SPRITE,
    PARSE_SPRITE_EIP712_DOMAIN_DISPATCH,
    PARSE_SPRITE_EIP712_DOMAIN_KEYWORD_NAME,
    PARSE_SPRITE_EIP712_DOMAIN_KEYWORD_VERSION,
    PARSE_SPRITE_EIP712_DOMAIN_KEYWORD_CHAIN_ID,
    PARSE_SPRITE_EIP712_DOMAIN_KEYWORD_VERIFYING_CONTRACT,
    PARSE_SPRITE_EIP712_DOMAIN_KEYWORD_SALT,
    PARSE_SPRITE_EIP712_DOMAIN_CHAIN_ID_CURRENT,
    PARSE_SPRITE_EIP712_DOMAIN_TYPE_PREFIX,
    PARSE_SPRITE_EIP712_DOMAIN_TYPE_SUFFIX,
    PARSE_SPRITE_EIP712_DOMAIN_TYPE_MEMBER_SEPARATOR,
    PARSE_SPRITE_EIP712_DOMAIN_MEMBER_NAME,
    PARSE_SPRITE_EIP712_DOMAIN_MEMBER_VERSION,
    PARSE_SPRITE_EIP712_DOMAIN_MEMBER_CHAIN_ID,
    PARSE_SPRITE_EIP712_DOMAIN_MEMBER_VERIFYING_CONTRACT,
    PARSE_SPRITE_EIP712_DOMAIN_MEMBER_SALT,
    PARSE_SPRITE_PRAGMA_KEYWORD
} from "../../../../src/lib/parse/LibParseSprite.sol";
import {
    EIP712_DOMAIN_SEPARATOR_DISPATCH,
    EIP712_DOMAIN_KEYWORD_NAME,
    EIP712_DOMAIN_KEYWORD_VERSION,
    EIP712_DOMAIN_KEYWORD_CHAIN_ID,
    EIP712_DOMAIN_KEYWORD_VERIFYING_CONTRACT,
    EIP712_DOMAIN_KEYWORD_SALT,
    EIP712_DOMAIN_CHAIN_ID_CURRENT,
    EIP712_DOMAIN_TYPE_PREFIX,
    EIP712_DOMAIN_TYPE_SUFFIX,
    EIP712_DOMAIN_TYPE_MEMBER_SEPARATOR,
    EIP712_DOMAIN_MEMBER_NAME,
    EIP712_DOMAIN_MEMBER_VERSION,
    EIP712_DOMAIN_MEMBER_CHAIN_ID,
    EIP712_DOMAIN_MEMBER_VERIFYING_CONTRACT,
    EIP712_DOMAIN_MEMBER_SALT
} from "../../../../src/lib/parse/literal/LibParseLiteralEIP712Domain.sol";
import {PRAGMA_KEYWORD_BYTES} from "../../../../src/lib/parse/LibParsePragma.sol";

contract LibParseSpriteEntriesTest is Test {
    function spriteSlice(uint256 entry) internal pure returns (bytes memory) {
        bytes memory sprite = PARSE_SPRITE;
        uint256 offset = entry >> 8;
        bytes memory slice = new bytes(entry & 0xFF);
        for (uint256 i = 0; i < slice.length; i++) {
            slice[i] = sprite[offset + i];
        }
        return slice;
    }

    /// Every sprite entry slices the sprite to exactly its named constant.
    function testSpriteEntriesSliceNamedConstants() external pure {
        assertEq(spriteSlice(PARSE_SPRITE_EIP712_DOMAIN_DISPATCH), EIP712_DOMAIN_SEPARATOR_DISPATCH, "dispatch");
        assertEq(spriteSlice(PARSE_SPRITE_EIP712_DOMAIN_KEYWORD_NAME), EIP712_DOMAIN_KEYWORD_NAME, "keyword name");
        assertEq(
            spriteSlice(PARSE_SPRITE_EIP712_DOMAIN_KEYWORD_VERSION), EIP712_DOMAIN_KEYWORD_VERSION, "keyword version"
        );
        assertEq(
            spriteSlice(PARSE_SPRITE_EIP712_DOMAIN_KEYWORD_CHAIN_ID), EIP712_DOMAIN_KEYWORD_CHAIN_ID, "keyword chain-id"
        );
        assertEq(
            spriteSlice(PARSE_SPRITE_EIP712_DOMAIN_KEYWORD_VERIFYING_CONTRACT),
            EIP712_DOMAIN_KEYWORD_VERIFYING_CONTRACT,
            "keyword verifying-contract"
        );
        assertEq(spriteSlice(PARSE_SPRITE_EIP712_DOMAIN_KEYWORD_SALT), EIP712_DOMAIN_KEYWORD_SALT, "keyword salt");
        assertEq(spriteSlice(PARSE_SPRITE_EIP712_DOMAIN_CHAIN_ID_CURRENT), EIP712_DOMAIN_CHAIN_ID_CURRENT, "current");
        assertEq(spriteSlice(PARSE_SPRITE_EIP712_DOMAIN_TYPE_PREFIX), EIP712_DOMAIN_TYPE_PREFIX, "type prefix");
        assertEq(spriteSlice(PARSE_SPRITE_EIP712_DOMAIN_TYPE_SUFFIX), EIP712_DOMAIN_TYPE_SUFFIX, "type suffix");
        assertEq(
            spriteSlice(PARSE_SPRITE_EIP712_DOMAIN_TYPE_MEMBER_SEPARATOR),
            EIP712_DOMAIN_TYPE_MEMBER_SEPARATOR,
            "type member separator"
        );
        assertEq(spriteSlice(PARSE_SPRITE_EIP712_DOMAIN_MEMBER_NAME), EIP712_DOMAIN_MEMBER_NAME, "member name");
        assertEq(
            spriteSlice(PARSE_SPRITE_EIP712_DOMAIN_MEMBER_VERSION), EIP712_DOMAIN_MEMBER_VERSION, "member version"
        );
        assertEq(
            spriteSlice(PARSE_SPRITE_EIP712_DOMAIN_MEMBER_CHAIN_ID), EIP712_DOMAIN_MEMBER_CHAIN_ID, "member chainId"
        );
        assertEq(
            spriteSlice(PARSE_SPRITE_EIP712_DOMAIN_MEMBER_VERIFYING_CONTRACT),
            EIP712_DOMAIN_MEMBER_VERIFYING_CONTRACT,
            "member verifyingContract"
        );
        assertEq(spriteSlice(PARSE_SPRITE_EIP712_DOMAIN_MEMBER_SALT), EIP712_DOMAIN_MEMBER_SALT, "member salt");
        assertEq(spriteSlice(PARSE_SPRITE_PRAGMA_KEYWORD), PRAGMA_KEYWORD_BYTES, "pragma keyword");
    }
}
