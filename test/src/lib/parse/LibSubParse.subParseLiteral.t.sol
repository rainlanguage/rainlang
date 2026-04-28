// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibSubParse} from "../../../../src/lib/parse/LibSubParse.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {LibBytes} from "rain.solmem/lib/LibBytes.sol";
import {ISubParserV4} from "rain.interpreter.interface/interface/ISubParserV4.sol";
import {UnsupportedLiteralType} from "../../../../src/error/ErrParse.sol";
import {SubParseLiteralDispatchLengthOverflow} from "../../../../src/error/ErrSubParse.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";

/// @title LibSubParseSubParseLiteralTest
/// @notice Direct unit tests for `LibSubParse.subParseLiteral`.
contract LibSubParseSubParseLiteralTest is Test {
    using LibParseState for ParseState;
    using LibSubParse for ParseState;
    using LibBytes for bytes;

    /// @notice External wrapper for subParseLiteral so vm.expectRevert works.
    function externalSubParseLiteral(bytes memory dispatch, bytes memory body, address[] memory subParserAddresses)
        external
        view
        returns (bytes32)
    {
        bytes memory data = bytes.concat(dispatch, body);
        ParseState memory state = LibParseState.newState(data, "", "", "");

        // Push sub parsers in reverse so the first address is tried first.
        for (uint256 i = subParserAddresses.length; i > 0; i--) {
            state.pushSubParser(0, bytes32(uint256(uint160(subParserAddresses[i - 1]))));
        }

        uint256 dataPtr = Pointer.unwrap(data.dataPointer());
        uint256 dispatchStart = dataPtr;
        uint256 dispatchEnd = dispatchStart + dispatch.length;
        uint256 bodyStart = dispatchEnd;
        uint256 bodyEnd = bodyStart + body.length;

        return state.subParseLiteral(dispatchStart, dispatchEnd, bodyStart, bodyEnd);
    }

    /// @notice Helper to build the expected sub-parse literal data payload.
    function buildExpectedData(bytes memory dispatch, bytes memory body) internal pure returns (bytes memory) {
        return bytes.concat(bytes2(uint16(dispatch.length)), dispatch, body);
    }

    /// @notice Single sub parser successfully resolves a literal.
    function testSubParseLiteralSingleSubParserSuccess() external {
        address subParser = makeAddr("subParser");
        bytes memory dispatch = bytes("foo");
        bytes memory body = bytes("bar");
        bytes32 expectedValue = bytes32(uint256(42));

        bytes memory expectedData = buildExpectedData(dispatch, body);
        vm.mockCall(
            subParser,
            abi.encodeWithSelector(ISubParserV4.subParseLiteral2.selector, expectedData),
            abi.encode(true, expectedValue)
        );

        address[] memory subs = new address[](1);
        subs[0] = subParser;

        bytes32 result = this.externalSubParseLiteral(dispatch, body, subs);
        assertEq(result, expectedValue);
    }

    /// @notice Single sub parser rejects the literal, causing
    /// UnsupportedLiteralType revert.
    function testSubParseLiteralSingleSubParserRejects() external {
        address subParser = makeAddr("subParser");
        bytes memory dispatch = bytes("foo");
        bytes memory body = bytes("bar");

        bytes memory expectedData = buildExpectedData(dispatch, body);
        vm.mockCall(
            subParser,
            abi.encodeWithSelector(ISubParserV4.subParseLiteral2.selector, expectedData),
            abi.encode(false, bytes32(0))
        );

        address[] memory subs = new address[](1);
        subs[0] = subParser;

        vm.expectRevert(abi.encodeWithSelector(UnsupportedLiteralType.selector, LibParseError.tagErrorOffset(0)));
        this.externalSubParseLiteral(dispatch, body, subs);
    }

    /// @notice First sub parser rejects, second accepts.
    function testSubParseLiteralFirstRejectsSecondAccepts() external {
        address first = makeAddr("first");
        address second = makeAddr("second");
        bytes memory dispatch = bytes("abc");
        bytes memory body = bytes("xyz");
        bytes32 expectedValue = bytes32(uint256(99));

        bytes memory expectedData = buildExpectedData(dispatch, body);
        vm.mockCall(
            first,
            abi.encodeWithSelector(ISubParserV4.subParseLiteral2.selector, expectedData),
            abi.encode(false, bytes32(0))
        );
        vm.mockCall(
            second,
            abi.encodeWithSelector(ISubParserV4.subParseLiteral2.selector, expectedData),
            abi.encode(true, expectedValue)
        );

        address[] memory subs = new address[](2);
        subs[0] = first;
        subs[1] = second;

        bytes32 result = this.externalSubParseLiteral(dispatch, body, subs);
        assertEq(result, expectedValue);
    }

    /// @notice Both sub parsers reject, causing UnsupportedLiteralType revert.
    function testSubParseLiteralAllReject() external {
        address first = makeAddr("first");
        address second = makeAddr("second");
        bytes memory dispatch = bytes("abc");
        bytes memory body = bytes("xyz");

        bytes memory expectedData = buildExpectedData(dispatch, body);
        vm.mockCall(
            first,
            abi.encodeWithSelector(ISubParserV4.subParseLiteral2.selector, expectedData),
            abi.encode(false, bytes32(0))
        );
        vm.mockCall(
            second,
            abi.encodeWithSelector(ISubParserV4.subParseLiteral2.selector, expectedData),
            abi.encode(false, bytes32(0))
        );

        address[] memory subs = new address[](2);
        subs[0] = first;
        subs[1] = second;

        vm.expectRevert(abi.encodeWithSelector(UnsupportedLiteralType.selector, LibParseError.tagErrorOffset(0)));
        this.externalSubParseLiteral(dispatch, body, subs);
    }

    /// @notice Empty body: only dispatch is present.
    function testSubParseLiteralEmptyBody() external {
        address subParser = makeAddr("subParser");
        bytes memory dispatch = bytes("pi");
        bytes memory body = bytes("");
        bytes32 expectedValue = bytes32(uint256(314));

        bytes memory expectedData = buildExpectedData(dispatch, body);
        vm.mockCall(
            subParser,
            abi.encodeWithSelector(ISubParserV4.subParseLiteral2.selector, expectedData),
            abi.encode(true, expectedValue)
        );

        address[] memory subs = new address[](1);
        subs[0] = subParser;

        bytes32 result = this.externalSubParseLiteral(dispatch, body, subs);
        assertEq(result, expectedValue);
    }

    /// Dispatch region exceeding 0xFFFF bytes reverts with
    /// SubParseLiteralDispatchLengthOverflow to prevent silent truncation
    /// of the 2-byte encoded length.
    function testSubParseLiteralDispatchLengthOverflow() external {
        address subParser = makeAddr("subParser");
        // Create a dispatch of 0x10001 bytes — one byte past the 16-bit max.
        bytes memory dispatch = new bytes(0x10001);
        bytes memory body = bytes("");

        vm.mockCall(
            subParser,
            abi.encodeWithSelector(ISubParserV4.subParseLiteral2.selector),
            abi.encode(true, bytes32(uint256(1)))
        );

        address[] memory subs = new address[](1);
        subs[0] = subParser;

        vm.expectRevert(abi.encodeWithSelector(SubParseLiteralDispatchLengthOverflow.selector, 0x10001));
        this.externalSubParseLiteral(dispatch, body, subs);
    }

    /// @notice First sub parser accepts, second is never called.
    function testSubParseLiteralFirstAcceptsSecondNotCalled() external {
        address first = makeAddr("first");
        address second = makeAddr("second");
        bytes memory dispatch = bytes("test");
        bytes memory body = bytes("data");
        bytes32 expectedValue = bytes32(uint256(7));

        bytes memory expectedData = buildExpectedData(dispatch, body);
        vm.mockCall(
            first,
            abi.encodeWithSelector(ISubParserV4.subParseLiteral2.selector, expectedData),
            abi.encode(true, expectedValue)
        );

        vm.expectCall(first, abi.encodeWithSelector(ISubParserV4.subParseLiteral2.selector, expectedData), 1);
        vm.expectCall(second, abi.encodeWithSelector(ISubParserV4.subParseLiteral2.selector, expectedData), 0);

        address[] memory subs = new address[](2);
        subs[0] = first;
        subs[1] = second;

        bytes32 result = this.externalSubParseLiteral(dispatch, body, subs);
        assertEq(result, expectedValue);
    }
}
