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
import {MalformedDecimalPoint} from "rain-math-float-0.3.11/src/error/ErrParse.sol";
import {ISubParserV4} from "../../../../src/interface/ISubParserV4.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {ConstantReturningSubParser} from "./ConstantReturningSubParser.sol";

contract LibParseLiteralEIP712DomainSeparatorTest is Test {
    using LibParse for ParseState;
    using Strings for address;

    function openZeppelinSeparator(
        bytes1 fields,
        string memory name,
        string memory version,
        uint256 chainId,
        address verifyingContract,
        bytes32 salt
    ) internal pure returns (bytes32) {
        return MessageHashUtils.toDomainSeparator(fields, name, version, chainId, verifyingContract, salt);
    }

    function externalParse(string memory src) external view returns (bytes memory, bytes32[] memory) {
        return LibMetaFixture.newState(src).parse();
    }

    /// The literal in an expression is its domain separator constant.
    function testParseEIP712DomainSeparatorLiteralIsConstant() external view {
        (, bytes32[] memory constants) =
            this.externalParse("_: [eip712-domain-separator name \"prices\" version \"1\"];");
        assertEq(constants.length, 1);
        assertEq(constants[0], openZeppelinSeparator(bytes1(0x03), "prices", "1", 0, address(0), 0));
    }

    /// A bare `chain-id` in an expression is the parsing chain's id.
    function testParseEIP712DomainSeparatorLiteralBareChainId(uint64 chainId) external {
        vm.chainId(chainId);
        (, bytes32[] memory constants) = this.externalParse("_: [eip712-domain-separator name \"prices\" chain-id];");
        assertEq(constants.length, 1);
        assertEq(constants[0], openZeppelinSeparator(bytes1(0x05), "prices", "", chainId, address(0), 0));
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
                " _ _: [eip712-domain-separator name \"prices\" version \"1\"] [other-dispatch body];"
            )
        );
        bytes32 separator = openZeppelinSeparator(bytes1(0x03), "prices", "1", 0, address(0), 0);
        assertEq(constants.length, 2);
        assertTrue(constants[0] == separator || constants[1] == separator);
        assertTrue(constants[0] == bytes32(uint256(99)) || constants[1] == bytes32(uint256(99)));
    }

    /// Every field in one literal, with a decimal literal `chain-id`.
    function testParseEIP712DomainSeparatorLiteralAllFields(address verifyingContract, bytes32 salt) external view {
        (, bytes32[] memory constants) = this.externalParse(
            string.concat(
                "_: [eip712-domain-separator name \"prices\" version \"1\" chain-id 1e3 verifying-contract ",
                verifyingContract.toHexString(),
                " salt ",
                vm.toString(salt),
                "];"
            )
        );
        assertEq(constants.length, 1);
        assertEq(constants[0], openZeppelinSeparator(bytes1(0x1f), "prices", "1", 1000, verifyingContract, salt));
    }

    /// Refusals carry their offset in the whole source, including the decimal
    /// parser's own errors.
    function testParseEIP712DomainSeparatorLiteralRefusalOffset() external {
        vm.expectRevert(abi.encodeWithSelector(MalformedEIP712DomainValue.selector, LibParseError.tagErrorOffset(32)));
        this.externalParse("_: [eip712-domain-separator name];");
        vm.expectRevert(abi.encodeWithSelector(MalformedEIP712DomainValue.selector, LibParseError.tagErrorOffset(33)));
        this.externalParse("_: [eip712-domain-separator name prices];");
        vm.expectRevert(abi.encodeWithSelector(MalformedEIP712DomainValue.selector, LibParseError.tagErrorOffset(37)));
        this.externalParse("_: [eip712-domain-separator chain-id 1.5];");
        vm.expectRevert(abi.encodeWithSelector(MalformedDecimalPoint.selector, LibParseError.tagErrorOffset(39)));
        this.externalParse("_: [eip712-domain-separator chain-id 1.];");
    }
}
