// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {ISubParserV4} from "rain.interpreter.interface/interface/ISubParserV4.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {BadSubParserResult} from "../../../../src/error/ErrParse.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

/// A bad sub parser that claims to know every word but returns bytecode of
/// the wrong length.
contract BadLengthSubParser is ISubParserV4, IERC165 {
    bytes public badBytecode;

    constructor(bytes memory badBytecode_) {
        badBytecode = badBytecode_;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(ISubParserV4).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function subParseLiteral2(bytes calldata) external pure override returns (bool, bytes32) {
        return (false, 0);
    }

    function subParseWord2(bytes calldata) external view override returns (bool, bytes memory, bytes32[] memory) {
        return (true, badBytecode, new bytes32[](0));
    }
}

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
