// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {
    RainlangReferenceExtern,
    StackItem,
    InvalidRepeatCount,
    UnconsumedRepeatDispatchBytes
} from "../../../src/concrete/extern/RainlangReferenceExtern.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract RainlangReferenceExternRepeatTest is OpTest {
    using Strings for address;

    function testRainlangReferenceExternRepeatHappy() external {
        RainlangReferenceExtern extern = new RainlangReferenceExtern();
        string memory baseStr = string.concat("using-words-from ", address(extern).toHexString(), " ");

        StackItem[] memory expectedStack = new StackItem[](1);
        expectedStack[0] = StackItem.wrap(bytes32(uint256(999)));

        checkHappy(
            bytes(string.concat(baseStr, "nineninenine: [ref-extern-repeat-9 abc];")), expectedStack, "repeat 9 abc"
        );

        expectedStack[0] = StackItem.wrap(bytes32(uint256(88)));
        checkHappy(bytes(string.concat(baseStr, "eighteight: [ref-extern-repeat-8 zz];")), expectedStack, "repeat 8 zz");
    }

    /// Repeat count 0 produces 0 regardless of body length.
    function testRainlangReferenceExternRepeatZero() external {
        RainlangReferenceExtern extern = new RainlangReferenceExtern();
        string memory baseStr = string.concat("using-words-from ", address(extern).toHexString(), " ");

        StackItem[] memory expectedStack = new StackItem[](1);
        expectedStack[0] = StackItem.wrap(bytes32(uint256(0)));

        checkHappy(bytes(string.concat(baseStr, "zero: [ref-extern-repeat-0 abc];")), expectedStack, "repeat 0 abc");

        checkHappy(bytes(string.concat(baseStr, "zerosingle: [ref-extern-repeat-0 x];")), expectedStack, "repeat 0 x");
    }

    /// Negative repeat count must revert with InvalidRepeatCount.
    function testRainlangReferenceExternRepeatNegative() external {
        RainlangReferenceExtern extern = new RainlangReferenceExtern();
        string memory baseStr = string.concat("using-words-from ", address(extern).toHexString(), " ");

        vm.expectRevert(abi.encodeWithSelector(InvalidRepeatCount.selector));
        bytes memory bytecode = I_DEPLOYER.parse2(bytes(string.concat(baseStr, "_: [ref-extern-repeat--1 abc];")));
        (bytecode);
    }

    /// Non-integer repeat count (e.g. 1.5) must revert with InvalidRepeatCount.
    function testRainlangReferenceExternRepeatNonInteger() external {
        RainlangReferenceExtern extern = new RainlangReferenceExtern();
        string memory baseStr = string.concat("using-words-from ", address(extern).toHexString(), " ");

        vm.expectRevert(abi.encodeWithSelector(InvalidRepeatCount.selector));
        bytes memory bytecode = I_DEPLOYER.parse2(bytes(string.concat(baseStr, "_: [ref-extern-repeat-1.5 abc];")));
        (bytecode);
    }

    /// Repeat count > 9 must revert with InvalidRepeatCount.
    function testRainlangReferenceExternRepeatTooLarge() external {
        RainlangReferenceExtern extern = new RainlangReferenceExtern();
        string memory baseStr = string.concat("using-words-from ", address(extern).toHexString(), " ");

        vm.expectRevert(abi.encodeWithSelector(InvalidRepeatCount.selector));
        bytes memory bytecode = I_DEPLOYER.parse2(bytes(string.concat(baseStr, "_: [ref-extern-repeat-10 abc];")));
        (bytecode);
    }

    /// Trailing bytes after the decimal digit must revert.
    function testRainlangReferenceExternRepeatTrailingBytes() external {
        RainlangReferenceExtern extern = new RainlangReferenceExtern();
        string memory baseStr = string.concat("using-words-from ", address(extern).toHexString(), " ");

        vm.expectRevert(abi.encodeWithSelector(UnconsumedRepeatDispatchBytes.selector));
        bytes memory bytecode = I_DEPLOYER.parse2(bytes(string.concat(baseStr, "_: [ref-extern-repeat-5x abc];")));
        (bytecode);
    }
}
