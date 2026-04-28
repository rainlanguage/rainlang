// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {ParseState, Pointer, LibParseState} from "../../../../../src/lib/parse/LibParseState.sol";
import {LibBytes} from "rain.solmem/lib/LibBytes.sol";
import {LibParseLiteralSubParseable} from "../../../../../src/lib/parse/literal/LibParseLiteralSubParseable.sol";
import {
    UnclosedSubParseableLiteral,
    SubParseableMissingDispatch,
    UnsupportedLiteralType
} from "../../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../../src/lib/parse/LibParseError.sol";
import {ISubParserV4} from "rain.interpreter.interface/interface/ISubParserV4.sol";
import {LibConformString} from "rain.string/lib/mut/LibConformString.sol";
import {CMASK_WHITESPACE, CMASK_SUB_PARSEABLE_LITERAL_END} from "rain.string/lib/parse/LibParseCMask.sol";
import {LibParseChar} from "rain.string/lib/parse/LibParseChar.sol";

contract LibParseLiteralSubParseableTest is Test {
    using LibBytes for bytes;
    using LibParseState for ParseState;
    using LibParseLiteralSubParseable for ParseState;

    function checkParseSubParseable(
        string memory data,
        string memory expectedDispatch,
        string memory expectedBody,
        uint256 expectedCursorAfter,
        bytes memory err
    ) public {
        ParseState memory state = LibParseState.newState(bytes(data), "", "", "");
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        address subParser = address(0x1234567890123456789012345678901234567890);
        state.pushSubParser(0, bytes32(uint256(uint160(subParser))));
        bytes memory subParseData =
            bytes.concat(bytes2(uint16(bytes(expectedDispatch).length)), bytes(expectedDispatch), bytes(expectedBody));
        bytes32 returnValue = bytes32(uint256(99));
        vm.mockCall(
            subParser,
            abi.encodeWithSelector(ISubParserV4.subParseLiteral2.selector, subParseData),
            abi.encode(true, returnValue)
        );
        if (bytes(err).length == 0) {
            vm.expectCall(subParser, abi.encodeWithSelector(ISubParserV4.subParseLiteral2.selector, subParseData));
        }
        (uint256 cursorAfter, bytes32 value) =
            state.parseSubParseable(cursor, Pointer.unwrap(state.data.endDataPointer()));
        assertEq(cursorAfter - cursor, expectedCursorAfter);
        assertEq(value, returnValue);
    }

    function checkParseSubParseable(
        string memory data,
        string memory expectedDispatch,
        string memory expectedBody,
        uint256 expectedCursorAfter
    ) internal {
        checkParseSubParseable(data, expectedDispatch, expectedBody, expectedCursorAfter, "");
    }

    function checkParseSubParseableError(string memory data, bytes memory err) internal {
        vm.expectRevert(err);
        this.checkParseSubParseable(data, "", "", 0, err);
    }

    /// An unclosed sub parseable literal is an error.
    function testParseLiteralSubParseableUnclosedDispatch0() external {
        checkParseSubParseableError(
            "[a", abi.encodeWithSelector(UnclosedSubParseableLiteral.selector, LibParseError.tagErrorOffset(2))
        );
    }

    /// Leading whitespace is not allowed.
    function testParseLiteralSubParseableUnclosedDispatchWhitespace1() external {
        checkParseSubParseableError(
            "[ a", abi.encodeWithSelector(SubParseableMissingDispatch.selector, LibParseError.tagErrorOffset(1))
        );
    }

    /// An unclosed sub parseable literal is an error.
    function testParseLiteralSubParseableUnclosedDispatchWhitespace0() external {
        checkParseSubParseableError(
            "[a ", abi.encodeWithSelector(UnclosedSubParseableLiteral.selector, LibParseError.tagErrorOffset(3))
        );
    }

    /// An unclosed sub parseable literal is an error.
    /// Tests with a body.
    function testParseLiteralSubParseableUnclosedDispatchBody() external {
        checkParseSubParseableError(
            "[a b", abi.encodeWithSelector(UnclosedSubParseableLiteral.selector, LibParseError.tagErrorOffset(4))
        );
    }

    /// An unclosed sub parseable literal is an error.
    function testParseLiteralSubParseableUnclosedDoubleOpen() external {
        checkParseSubParseableError(
            "[[", abi.encodeWithSelector(UnclosedSubParseableLiteral.selector, LibParseError.tagErrorOffset(2))
        );
    }

    /// An empty sub parseable literal is an error.
    function testParseLiteralSubParseableMissingDispatchEmpty() external {
        checkParseSubParseableError(
            "[]", abi.encodeWithSelector(SubParseableMissingDispatch.selector, LibParseError.tagErrorOffset(1))
        );
    }

    /// An unclosed sub parseable literal with no dispatch is an error.
    function testParseLiteralSubParseableMissingDispatchUnclosed() external {
        checkParseSubParseableError(
            "[", abi.encodeWithSelector(SubParseableMissingDispatch.selector, LibParseError.tagErrorOffset(1))
        );
    }

    /// An unclosed sub parseable literal with no dispatch is an error.
    function testParseLiteralSubParseableMissingDispatchUnclosedWhitespace0() external {
        checkParseSubParseableError(
            "[ ", abi.encodeWithSelector(SubParseableMissingDispatch.selector, LibParseError.tagErrorOffset(1))
        );
    }

    /// An unclosed sub parseable literal with no dispatch is an error.
    function testParseLiteralSubParseableMissingDispatchUnclosedWhitespace1() external {
        checkParseSubParseableError(
            "[  ", abi.encodeWithSelector(SubParseableMissingDispatch.selector, LibParseError.tagErrorOffset(1))
        );
    }

    /// A dispatch with an empty body is allowed. Trailing whitespace is ignored.
    function testParseLiteralSubParseableEmptyBody() external {
        checkParseSubParseable("[pi]", "pi", "", 4);
        checkParseSubParseable("[pi ]", "pi", "", 5);
    }

    /// A dispatch with a body is allowed. Whitespace after the body start is
    /// included in the body.
    function testParseLiteralSubParseableBody() external {
        checkParseSubParseable("[hi a]", "hi", "a", 6);
        checkParseSubParseable("[hi a ]", "hi", "a ", 7);
        // Multiple whitespace between dispatch and body is allowed.
        checkParseSubParseable("[hi  a ]", "hi", "a ", 8);
        checkParseSubParseable("[hi a  ]", "hi", "a  ", 8);
        // Different whitespace such as a newline is allowed as a delimiter.
        checkParseSubParseable("[hi\na]", "hi", "a", 6);
        checkParseSubParseable("[hi\na ]", "hi", "a ", 7);
        checkParseSubParseable("[hi\na\n]", "hi", "a\n", 7);
        // Examples from fuzzing.
        checkParseSubParseable("[[pi\n\n\n\na]", "[pi", "a", 10);
    }

    /// Fuzz the happy path.
    function testParseLiteralSubParseableHappyFuzz(string memory dispatch, string memory whitespace, string memory body)
        public
    {
        vm.assume(bytes(dispatch).length > 0);
        vm.assume(bytes(whitespace).length > 0);

        // Dispatch can be any ASCII other than whitespace or literal end char.
        LibConformString.conformStringToMask(dispatch, ~(CMASK_WHITESPACE | CMASK_SUB_PARSEABLE_LITERAL_END));
        // Whitespace can be any standard rainlang whitespace.
        LibConformString.conformStringToWhitespace(whitespace);
        // Body can be any ASCII other than the literal end, including
        // whitespace.
        LibConformString.conformStringToMask(body, ~CMASK_SUB_PARSEABLE_LITERAL_END);

        string memory data = string(abi.encodePacked("[", dispatch, whitespace, body, "]"));

        // Expected body excludes any leading whitespace in the body.
        string memory expectedBody = string.concat(body);
        uint256 cursor;
        uint256 end;
        assembly ("memory-safe") {
            cursor := add(expectedBody, 0x20)
            end := add(cursor, mload(expectedBody))
        }
        cursor = LibParseChar.skipMask(cursor, end, CMASK_WHITESPACE);
        assembly ("memory-safe") {
            let whitespaceLength := sub(cursor, add(expectedBody, 0x20))
            mstore(expectedBody, sub(mload(expectedBody), whitespaceLength))
            mcopy(add(expectedBody, 0x20), cursor, mload(expectedBody))
        }

        checkParseSubParseable(
            data, dispatch, expectedBody, bytes(dispatch).length + bytes(whitespace).length + bytes(body).length + 2
        );
    }

    /// External wrapper that constructs data with a `]` past the logical end.
    /// The assembly shrinks the length after allocation so `]` remains in
    /// memory but is past `end`.
    function parseSubParseableBracketPastEnd(bytes memory data) external view {
        assembly ("memory-safe") {
            mstore(data, sub(mload(data), 1))
        }
        ParseState memory state = LibParseState.newState(data, "", "", "");
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        uint256 end = cursor + data.length;
        state.parseSubParseable(cursor, end);
    }

    /// A `]` sitting in memory just past `end` must not cause the parser to
    /// incorrectly accept the literal. We construct a string ending in `]`
    /// then shrink its length by 1 so `]` is still in memory but logically
    /// past the end of the data.
    function testParseLiteralSubParseableUnclosedBracketPastEnd() external {
        vm.expectRevert(abi.encodeWithSelector(UnclosedSubParseableLiteral.selector, LibParseError.tagErrorOffset(4)));
        this.parseSubParseableBracketPastEnd(bytes("[a b]"));
    }

    function testParseLiteralSubParseableHappyKnown() external {
        testParseLiteralSubParseableHappyFuzz("2 max-positive-value() 2", unicode"3¹&\\u{a3c}È", " ,");
    }

    function externalParseWithTwoSubParsers(bytes memory data, address subParserA, address subParserB)
        external
        view
        returns (uint256, bytes32)
    {
        ParseState memory state = LibParseState.newState(data, "", "", "");
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        uint256 end = Pointer.unwrap(state.data.endDataPointer());
        // B is pushed first so A (pushed last) is tried first.
        state.pushSubParser(0, bytes32(uint256(uint160(subParserB))));
        state.pushSubParser(0, bytes32(uint256(uint160(subParserA))));
        return state.parseSubParseable(cursor, end);
    }

    function mockSubParseLiteral(address subParser, bool success, bytes32 value) internal {
        bytes memory subParseData = bytes.concat(bytes2(uint16(3)), bytes("foo"));
        vm.mockCall(
            subParser,
            abi.encodeWithSelector(ISubParserV4.subParseLiteral2.selector, subParseData),
            abi.encode(success, value)
        );
    }

    /// When the first sub-parser returns (false, ...), subParseLiteral must
    /// continue to the next sub-parser. If the second returns (true, value),
    /// that value is used.
    function testSubParseLiteralFirstRejectsSecondAccepts(string memory nameA, string memory nameB) external {
        address first = makeAddr(nameA);
        address second = makeAddr(nameB);
        vm.assume(first != second);

        mockSubParseLiteral(first, false, bytes32(0));
        mockSubParseLiteral(second, true, bytes32(uint256(42)));

        (, bytes32 value) = this.externalParseWithTwoSubParsers(bytes("[foo]"), first, second);
        assertEq(value, bytes32(uint256(42)));
    }

    /// When all sub-parsers return (false, ...), subParseLiteral must revert
    /// with UnsupportedLiteralType.
    function testSubParseLiteralAllReject(string memory nameA, string memory nameB) external {
        address first = makeAddr(nameA);
        address second = makeAddr(nameB);
        vm.assume(first != second);

        mockSubParseLiteral(first, false, bytes32(0));
        mockSubParseLiteral(second, false, bytes32(0));

        vm.expectRevert(abi.encodeWithSelector(UnsupportedLiteralType.selector, LibParseError.tagErrorOffset(1)));
        this.externalParseWithTwoSubParsers(bytes("[foo]"), first, second);
    }
}
