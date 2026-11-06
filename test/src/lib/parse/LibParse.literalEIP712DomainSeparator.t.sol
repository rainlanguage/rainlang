// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.7.0/utils/cryptography/MessageHashUtils.sol";
import {Strings} from "@openzeppelin-contracts-5.7.0/utils/Strings.sol";
import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";
import {MalformedEIP712DomainValue} from "../../../../src/error/ErrParse.sol";
import {ISubParserV4} from "../../../../src/interface/ISubParserV4.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {ConstantReturningSubParser} from "./ConstantReturningSubParser.sol";

contract LibParseLiteralEIP712DomainSeparatorTest is Test {
    using LibParse for ParseState;
    using Strings for address;

    function externalParse(string memory src) external view returns (bytes memory, bytes32[] memory) {
        return LibMetaFixture.newState(src).parse();
    }

    /// The literal in an expression is its domain separator constant.
    function testParseEIP712DomainSeparatorLiteralIsConstant() external view {
        (, bytes32[] memory constants) = this.externalParse("_: [eip712-domain-separator name prices version 1];");
        assertEq(constants.length, 1);
        assertEq(constants[0], MessageHashUtils.toDomainSeparator(bytes1(0x03), "prices", "1", 0, address(0), 0));
    }

    /// A bare `chainId` in an expression is the parsing chain's id.
    function testParseEIP712DomainSeparatorLiteralBareChainId(uint64 chainId) external {
        vm.chainId(chainId);
        (, bytes32[] memory constants) = this.externalParse("_: [eip712-domain-separator name prices chainId];");
        assertEq(constants.length, 1);
        assertEq(constants[0], MessageHashUtils.toDomainSeparator(bytes1(0x05), "prices", "", chainId, address(0), 0));
    }

    /// Under `using-words-from` a sub-parser that accepts every literal
    /// answers other dispatches but not `eip712-domain-separator`.
    function testParseEIP712DomainSeparatorLiteralBeatsUsingWordsFrom() external {
        ConstantReturningSubParser sub = new ConstantReturningSubParser();
        vm.mockCall(
            address(sub),
            abi.encodeWithSelector(ISubParserV4.subParseLiteral2.selector),
            abi.encode(true, bytes32(uint256(99)))
        );
        (, bytes32[] memory constants) = this.externalParse(
            string.concat(
                "using-words-from ",
                address(sub).toHexString(),
                " _ _: [eip712-domain-separator name prices version 1] [other-dispatch body];"
            )
        );
        bytes32 separator = MessageHashUtils.toDomainSeparator(bytes1(0x03), "prices", "1", 0, address(0), 0);
        assertEq(constants.length, 2);
        assertTrue(constants[0] == separator || constants[1] == separator);
        assertTrue(constants[0] == bytes32(uint256(99)) || constants[1] == bytes32(uint256(99)));
    }

    /// A refusal carries its offset in the whole source.
    function testParseEIP712DomainSeparatorLiteralRefusalOffset() external {
        vm.expectRevert(abi.encodeWithSelector(MalformedEIP712DomainValue.selector, LibParseError.tagErrorOffset(32)));
        this.externalParse("_: [eip712-domain-separator name];");
    }
}
