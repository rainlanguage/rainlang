// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {Strings} from "@openzeppelin-contracts-5.6.1/utils/Strings.sol";
import {RainlangReferenceExtern, StackItem} from "../../../src/concrete/extern/RainlangReferenceExtern.sol";
import {SignedContextV1} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterCallerV4.sol";
import {LibContext} from "rain-interpreter-interface-0.1.0/src/lib/caller/LibContext.sol";

contract RainlangReferenceExternContextRainlenTest is OpTest {
    using Strings for address;

    function testRainlangReferenceExternContextRainlenHappy() external {
        RainlangReferenceExtern extern = new RainlangReferenceExtern();

        bytes memory rainlang = bytes(
            string.concat("using-words-from ", address(extern).toHexString(), " rainlen: ref-extern-context-rainlen();")
        );

        StackItem[] memory expectedStack = new StackItem[](1);
        expectedStack[0] = StackItem.wrap(bytes32(rainlang.length));

        bytes32[][] memory callerContext = new bytes32[][](1);
        callerContext[0] = new bytes32[](1);
        callerContext[0][0] = bytes32(rainlang.length);

        checkHappy(rainlang, LibContext.build(callerContext, new SignedContextV1[](0)), expectedStack, "rainlen");
    }
}
