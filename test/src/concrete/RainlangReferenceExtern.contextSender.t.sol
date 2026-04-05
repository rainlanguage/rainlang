// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {RainlangReferenceExtern, StackItem} from "../../../src/concrete/extern/RainlangReferenceExtern.sol";

contract RainlangReferenceExternContextSenderTest is OpTest {
    using Strings for address;

    function testRainlangReferenceExternContextSenderHappy() external {
        RainlangReferenceExtern extern = new RainlangReferenceExtern();

        StackItem[] memory expectedStack = new StackItem[](1);
        expectedStack[0] = StackItem.wrap(bytes32(uint256(uint160(msg.sender))));

        checkHappy(
            bytes(
                string.concat(
                    "using-words-from ", address(extern).toHexString(), " sender: ref-extern-context-sender();"
                )
            ),
            expectedStack,
            "sender"
        );
    }
}
