// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {RainlangReferenceExtern} from "../../../src/concrete/extern/RainlangReferenceExtern.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {UnknownWord} from "../../../src/error/ErrParse.sol";

contract RainlangReferenceExternUnknownWordTest is OpTest {
    using Strings for address;

    function testRainlangReferenceExternUnknownWord() external {
        RainlangReferenceExtern extern = new RainlangReferenceExtern();

        checkUnhappyParse(
            bytes(string.concat("using-words-from ", address(extern).toHexString(), " _: not-a-word();")),
            abi.encodeWithSelector(UnknownWord.selector, "not-a-word")
        );
    }
}
