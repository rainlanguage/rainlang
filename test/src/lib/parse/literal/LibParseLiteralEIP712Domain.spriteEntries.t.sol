// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {
    EIP712_DOMAIN_SPRITE,
    EIP712_DOMAIN_SPRITE_DISPATCH,
    EIP712_DOMAIN_SPRITE_KEYWORD_NAME,
    EIP712_DOMAIN_SPRITE_KEYWORD_VERSION,
    EIP712_DOMAIN_SPRITE_KEYWORD_CHAIN_ID,
    EIP712_DOMAIN_SPRITE_KEYWORD_VERIFYING_CONTRACT,
    EIP712_DOMAIN_SPRITE_KEYWORD_SALT,
    EIP712_DOMAIN_SPRITE_CHAIN_ID_CURRENT,
    EIP712_DOMAIN_SPRITE_TYPE_PREFIX,
    EIP712_DOMAIN_SPRITE_TYPE_SUFFIX,
    EIP712_DOMAIN_SPRITE_TYPE_MEMBER_SEPARATOR,
    EIP712_DOMAIN_SPRITE_MEMBER_NAME,
    EIP712_DOMAIN_SPRITE_MEMBER_VERSION,
    EIP712_DOMAIN_SPRITE_MEMBER_CHAIN_ID,
    EIP712_DOMAIN_SPRITE_MEMBER_VERIFYING_CONTRACT,
    EIP712_DOMAIN_SPRITE_MEMBER_SALT,
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
} from "../../../../../src/lib/parse/literal/LibParseLiteralEIP712Domain.sol";

contract LibParseLiteralEIP712DomainSpriteEntriesTest is Test {
    function spriteSlice(uint256 entry) internal pure returns (bytes memory) {
        bytes memory sprite = EIP712_DOMAIN_SPRITE;
        uint256 offset = entry >> 8;
        bytes memory slice = new bytes(entry & 0xFF);
        for (uint256 i = 0; i < slice.length; i++) {
            slice[i] = sprite[offset + i];
        }
        return slice;
    }

    /// Every sprite entry slices the sprite to exactly its named constant.
    function testSpriteEntriesSliceNamedConstants() external pure {
        assertEq(spriteSlice(EIP712_DOMAIN_SPRITE_DISPATCH), EIP712_DOMAIN_SEPARATOR_DISPATCH, "dispatch");
        assertEq(spriteSlice(EIP712_DOMAIN_SPRITE_KEYWORD_NAME), EIP712_DOMAIN_KEYWORD_NAME, "keyword name");
        assertEq(spriteSlice(EIP712_DOMAIN_SPRITE_KEYWORD_VERSION), EIP712_DOMAIN_KEYWORD_VERSION, "keyword version");
        assertEq(spriteSlice(EIP712_DOMAIN_SPRITE_KEYWORD_CHAIN_ID), EIP712_DOMAIN_KEYWORD_CHAIN_ID, "keyword chain-id");
        assertEq(
            spriteSlice(EIP712_DOMAIN_SPRITE_KEYWORD_VERIFYING_CONTRACT),
            EIP712_DOMAIN_KEYWORD_VERIFYING_CONTRACT,
            "keyword verifying-contract"
        );
        assertEq(spriteSlice(EIP712_DOMAIN_SPRITE_KEYWORD_SALT), EIP712_DOMAIN_KEYWORD_SALT, "keyword salt");
        assertEq(spriteSlice(EIP712_DOMAIN_SPRITE_CHAIN_ID_CURRENT), EIP712_DOMAIN_CHAIN_ID_CURRENT, "current");
        assertEq(spriteSlice(EIP712_DOMAIN_SPRITE_TYPE_PREFIX), EIP712_DOMAIN_TYPE_PREFIX, "type prefix");
        assertEq(spriteSlice(EIP712_DOMAIN_SPRITE_TYPE_SUFFIX), EIP712_DOMAIN_TYPE_SUFFIX, "type suffix");
        assertEq(
            spriteSlice(EIP712_DOMAIN_SPRITE_TYPE_MEMBER_SEPARATOR),
            EIP712_DOMAIN_TYPE_MEMBER_SEPARATOR,
            "type member separator"
        );
        assertEq(spriteSlice(EIP712_DOMAIN_SPRITE_MEMBER_NAME), EIP712_DOMAIN_MEMBER_NAME, "member name");
        assertEq(spriteSlice(EIP712_DOMAIN_SPRITE_MEMBER_VERSION), EIP712_DOMAIN_MEMBER_VERSION, "member version");
        assertEq(spriteSlice(EIP712_DOMAIN_SPRITE_MEMBER_CHAIN_ID), EIP712_DOMAIN_MEMBER_CHAIN_ID, "member chainId");
        assertEq(
            spriteSlice(EIP712_DOMAIN_SPRITE_MEMBER_VERIFYING_CONTRACT),
            EIP712_DOMAIN_MEMBER_VERIFYING_CONTRACT,
            "member verifyingContract"
        );
        assertEq(spriteSlice(EIP712_DOMAIN_SPRITE_MEMBER_SALT), EIP712_DOMAIN_MEMBER_SALT, "member salt");
    }
}
