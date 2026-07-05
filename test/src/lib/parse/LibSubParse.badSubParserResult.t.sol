// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {BadSubParserResult} from "../../../../src/error/ErrParse.sol";
import {Strings} from "@openzeppelin-contracts-5.6.1/utils/Strings.sol";
import {BadLengthSubParser} from "./BadLengthSubParser.sol";

/// @title LibSubParseBadSubParserResultTest
/// @notice Tests that parsing reverts with `BadSubParserResult` when a sub parser
/// returns success with bytecode that is not exactly 4 bytes.
contract LibSubParseBadSubParserResultTest is OpTest {
    using Strings for address;

    function checkBadSubParserResult(bytes memory badBytecodeValue) internal {
        BadLengthSubParser bad = new BadLengthSubParser(badBytecodeValue);
        checkUnhappyParse(
            bytes(string.concat("using-words-from ", address(bad).toHexString(), " _: some-unknown-word();")),
            abi.encodeWithSelector(BadSubParserResult.selector, badBytecodeValue)
        );
    }

    /// Test that a sub parser returning 0 bytes of bytecode reverts.
    function testBadSubParserResultEmpty() external {
        checkBadSubParserResult(hex"");
    }

    /// Test that a sub parser returning 3 bytes of bytecode reverts.
    function testBadSubParserResultTooShort() external {
        checkBadSubParserResult(hex"010203");
    }

    /// Test that a sub parser returning 5 bytes of bytecode reverts.
    function testBadSubParserResultTooLong() external {
        checkBadSubParserResult(hex"0102030405");
    }

    /// Test that a sub parser returning 8 bytes of bytecode reverts.
    function testBadSubParserResultWayTooLong() external {
        checkBadSubParserResult(hex"0102030405060708");
    }
}
