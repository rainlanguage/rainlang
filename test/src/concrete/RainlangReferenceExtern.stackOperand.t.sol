// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {RainlangReferenceExtern, StackItem} from "../../../src/concrete/extern/RainlangReferenceExtern.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract RainlangReferenceExternStackOperandTest is OpTest {
    using Strings for address;
    using Strings for uint256;

    function testRainlangReferenceExternStackOperandSingle(uint256 value) external {
        value = bound(value, 0, type(uint16).max);
        RainlangReferenceExtern extern = new RainlangReferenceExtern();

        StackItem[] memory expectedStack = new StackItem[](1);
        expectedStack[0] = StackItem.wrap(bytes32(value));

        checkHappy(
            bytes(
                string.concat(
                    "using-words-from ",
                    address(extern).toHexString(),
                    " _: ref-extern-stack-operand<",
                    value.toString(),
                    ">();"
                )
            ),
            expectedStack,
            "stack operand"
        );
    }
}
