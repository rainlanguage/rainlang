// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {LibParseState, ParseState, SUB_PARSER_POINTER_SHIFT} from "../../../../src/lib/parse/LibParseState.sol";
import {
    LibParsePragma,
    PRAGMA_KEYWORD_BYTES_LENGTH,
    PRAGMA_KEYWORD_BYTES
} from "../../../../src/lib/parse/LibParsePragma.sol";
import {LibBytes, Pointer} from "rain.solmem/lib/LibBytes.sol";
import {
    CMASK_WHITESPACE,
    CMASK_LITERAL_HEX_DISPATCH_START,
    CMASK_INTERSTITIAL_HEAD,
    CMASK_HEX
} from "rain.string/lib/parse/LibParseCMask.sol";
import {LibConformString} from "rain.string/lib/mut/LibConformString.sol";
import {NoWhitespaceAfterUsingWordsFrom} from "../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {LibAllStandardOps} from "../../../../src/lib/op/LibAllStandardOps.sol";

/// @title LibParsePragmaKeywordTest
/// @notice Tests for pragma keyword parsing.
contract LibParsePragmaKeywordTest is Test {
    using LibParsePragma for ParseState;
    using LibBytes for bytes;
    using Strings for address;

    function checkPragmaParsing(
        string memory str,
        uint256 expectedCursorDiff,
        address[] memory values,
        string memory err
    ) internal view {
        ParseState memory state = LibParseState.newState(
            bytes(str), "", "", LibAllStandardOps.literalParserFunctionPointers()
        );
        uint256 cursor = Pointer.unwrap(bytes(str).dataPointer());
        uint256 end = Pointer.unwrap(bytes(str).endDataPointer());
        uint256 cursorAfter = state.parsePragma(cursor, end);
        assertEq(cursorAfter - cursor, expectedCursorDiff, err);

        if (values.length > 0) {
            uint256 j = values.length - 1;
            bytes32 deref = state.subParsers;
            uint256 pointer = uint256(deref) >> SUB_PARSER_POINTER_SHIFT;
            while (deref != 0) {
                assertEq(uint160(uint256(deref)), uint160(values[j]));

                assembly ("memory-safe") {
                    deref := mload(pointer)
                }
                pointer = uint256(deref) >> SUB_PARSER_POINTER_SHIFT;
                // This underflows exactly when deref is zero and the loop
                // terminates.
                unchecked {
                    --j;
                }
            }
        }
    }

    function externalParsePragma(string memory str) external view {
        ParseState memory state =
            LibParseState.newState(bytes(str), "", "", LibAllStandardOps.literalParserFunctionPointers());
        uint256 cursor = Pointer.unwrap(bytes(str).dataPointer());
        uint256 end = Pointer.unwrap(bytes(str).endDataPointer());
        uint256 cursorAfter = state.parsePragma(cursor, end);
        (cursorAfter);
    }

    /// Anything that DOES NOT start with the keyword should be a noop.
    /// forge-config: default.fuzz.runs = 100
    function testPragmaKeywordNoop(ParseState memory state, string calldata calldataStr) external view {
        if (bytes(calldataStr).length >= PRAGMA_KEYWORD_BYTES_LENGTH) {
            bytes memory prefix = bytes(calldataStr)[0:PRAGMA_KEYWORD_BYTES_LENGTH];
            vm.assume(keccak256(prefix) != keccak256(PRAGMA_KEYWORD_BYTES));
        }
        string memory str = calldataStr;

        uint256 cursor = Pointer.unwrap(bytes(str).dataPointer());
        uint256 end = Pointer.unwrap(bytes(str).endDataPointer());
        uint256 cursorAfter = state.parsePragma(cursor, end);
        assertEq(cursorAfter, cursor);
    }

    /// Input ends exactly at the keyword boundary with no trailing bytes.
    /// Hits the `cursor >= end` revert at line 55.
    function testPragmaKeywordEndAtKeyword() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                NoWhitespaceAfterUsingWordsFrom.selector, LibParseError.tagErrorOffset(PRAGMA_KEYWORD_BYTES_LENGTH)
            )
        );
        this.externalParsePragma(string(PRAGMA_KEYWORD_BYTES));
    }

    /// Anything that DOES start with the keyword but WITHOUT whitespace should
    /// error.
    /// forge-config: default.fuzz.runs = 100
    function testPragmaKeywordNoWhitespace(uint256 seed, string memory str) external {
        bytes1 notWhitespace = LibConformString.charFromMask(seed, ~CMASK_WHITESPACE);
        string memory fullString =
            string.concat(string(PRAGMA_KEYWORD_BYTES), string(abi.encodePacked(notWhitespace)), str);
        vm.expectRevert(
            abi.encodeWithSelector(
                NoWhitespaceAfterUsingWordsFrom.selector, LibParseError.tagErrorOffset(PRAGMA_KEYWORD_BYTES_LENGTH)
            )
        );
        this.externalParsePragma(fullString);
    }

    /// Anything that DOES start with the keyword and WITH whitespace BUT NOT
    /// hex values should more the cursor forward exactly the length of the
    /// keyword + the whitespace char.
    /// forge-config: default.fuzz.runs = 100
    function testPragmaKeywordWhitespaceNoHex(uint256 seed, string calldata calldataStr) external view {
        seed = bound(seed, 0, type(uint256).max - 1);
        bytes1 whitespace = LibConformString.charFromMask(seed, CMASK_WHITESPACE);
        bytes1 notInterstitialHead = LibConformString.charFromMask(seed + 1, ~CMASK_INTERSTITIAL_HEAD);
        if (bytes(calldataStr).length > 2) {
            vm.assume(
                keccak256(bytes(calldataStr[0:2]))
                    // CMASK_LITERAL_HEX_DISPATCH_START is a constant that is
                    // definitely a uint16 so this is safe.
                    //forge-lint: disable-next-line(unsafe-typecast)
                    != keccak256(abi.encodePacked(uint16(CMASK_LITERAL_HEX_DISPATCH_START)))
            );
        }
        string memory str = string.concat(
            string(PRAGMA_KEYWORD_BYTES), string(abi.encodePacked(whitespace, notInterstitialHead)), calldataStr
        );
        ParseState memory state =
            LibParseState.newState(bytes(str), "", "", LibAllStandardOps.literalParserFunctionPointers());

        uint256 cursor = Pointer.unwrap(bytes(str).dataPointer());
        uint256 end = Pointer.unwrap(bytes(str).endDataPointer());
        uint256 cursorAfter = state.parsePragma(cursor, end);
        assertEq(cursorAfter, cursor + PRAGMA_KEYWORD_BYTES_LENGTH + 1);
    }

    /// Anything that DOES start with the keyword and WITH whitespace then some
    /// hex address should push the hex address to the state as a sub parser.
    /// forge-config: default.fuzz.runs = 100
    function testPragmaKeywordParseSubParserBasic(
        string memory whitespace,
        address subParser,
        uint256 seed,
        string calldata suffix
    ) external view {
        vm.assume(bytes(whitespace).length > 0);
        bytes1 notHexData = LibConformString.charFromMask(seed, ~CMASK_HEX);
        LibConformString.conformStringToMask(whitespace, CMASK_WHITESPACE, 0x80);
        string memory str = string.concat(
            string(PRAGMA_KEYWORD_BYTES),
            whitespace,
            subParser.toHexString(),
            string(abi.encodePacked(notHexData)),
            suffix
        );
        ParseState memory state =
            LibParseState.newState(bytes(str), "", "", LibAllStandardOps.literalParserFunctionPointers());
        uint256 cursor = Pointer.unwrap(bytes(str).dataPointer());
        uint256 end = Pointer.unwrap(bytes(str).endDataPointer());
        uint256 cursorAfter = state.parsePragma(cursor, end);

        // The cursor should be pointing after the sub parser.
        assertEq(cursorAfter, cursor + PRAGMA_KEYWORD_BYTES_LENGTH + bytes(whitespace).length + 42);

        // The sub parser should be pushed to the state.
        bytes32 deref = state.subParsers;
        assertEq(uint160(uint256(deref)), uint160(subParser));
        uint256 pointer = uint256(deref) >> SUB_PARSER_POINTER_SHIFT;
        assembly ("memory-safe") {
            deref := mload(pointer)
        }
        assertEq(deref, 0);
    }

    /// Can parse a couple of addresses cleanly.
    /// forge-config: default.fuzz.runs = 100
    function testPragmaKeywordParseSubParserCoupleOfAddresses(
        string memory whitespace0,
        string memory whitespace1,
        address subParser0,
        address subParser1,
        uint256 seed,
        string calldata suffix
    ) external view {
        vm.assume(bytes(whitespace0).length > 0);
        vm.assume(bytes(whitespace1).length > 0);

        bytes1 notHexData = LibConformString.charFromMask(seed, ~CMASK_HEX);

        LibConformString.conformStringToMask(whitespace0, CMASK_WHITESPACE, 0x80);
        LibConformString.conformStringToMask(whitespace1, CMASK_WHITESPACE, 0x80);

        string memory str = string.concat(
            string.concat(
                string(PRAGMA_KEYWORD_BYTES),
                whitespace0,
                subParser0.toHexString(),
                whitespace1,
                subParser1.toHexString(),
                string(abi.encodePacked(notHexData))
            ),
            suffix
        );

        ParseState memory state =
            LibParseState.newState(bytes(str), "", "", LibAllStandardOps.literalParserFunctionPointers());

        uint256 cursor = Pointer.unwrap(bytes(str).dataPointer());
        uint256 end = Pointer.unwrap(bytes(str).endDataPointer());
        uint256 cursorAfter = state.parsePragma(cursor, end);

        // The cursor should be pointing after the sub parser.
        assertEq(
            cursorAfter,
            cursor + PRAGMA_KEYWORD_BYTES_LENGTH + bytes(whitespace0).length + 42 + bytes(whitespace1).length + 42
        );

        // The sub parsers should both be pushed to the state.
        bytes32 deref = state.subParsers;
        assertEq(uint160(uint256(deref)), uint160(subParser1));
        uint256 pointer = uint256(deref) >> SUB_PARSER_POINTER_SHIFT;
        assembly ("memory-safe") {
            deref := mload(pointer)
        }
        assertEq(uint160(uint256(deref)), uint160(subParser0));
        pointer = uint256(deref) >> SUB_PARSER_POINTER_SHIFT;
        assembly ("memory-safe") {
            deref := mload(pointer)
        }
        assertEq(deref, 0);
    }

    /// Two pragmas in sequence. The first parsePragma call stops at the second
    /// keyword. Calling parsePragma again from that cursor parses the second.
    function testPragmaKeywordTwoSequentialPragmas() external view {
        address addr1 = 0x1234567890123456789012345678901234567890;
        address addr2 = 0x0987654321098765432109876543210987654321;
        string memory str =
            string.concat("using-words-from ", addr1.toHexString(), " using-words-from ", addr2.toHexString());
        ParseState memory state =
            LibParseState.newState(bytes(str), "", "", LibAllStandardOps.literalParserFunctionPointers());
        uint256 cursor = Pointer.unwrap(bytes(str).dataPointer());
        uint256 end = Pointer.unwrap(bytes(str).endDataPointer());

        // First pragma: "using-words-from " (17) + 42-char address + " " interstitial = 60.
        uint256 cursor2 = state.parsePragma(cursor, end);
        assertEq(cursor2, cursor + 60, "first pragma cursor");

        // Second pragma parses the second address.
        uint256 cursor3 = state.parsePragma(cursor2, end);
        assertEq(cursor3, end, "should reach end");

        // Both sub parsers should be in the linked list.
        bytes32 deref = state.subParsers;
        assertEq(uint160(uint256(deref)), uint160(addr2), "second address");
        uint256 pointer = uint256(deref) >> SUB_PARSER_POINTER_SHIFT;
        assembly ("memory-safe") {
            deref := mload(pointer)
        }
        assertEq(uint160(uint256(deref)), uint160(addr1), "first address");
        // The list must terminate: dereferencing the first node's next pointer
        // yields zero (the initial empty subParsers value).
        uint256 nextPointer = uint256(deref) >> SUB_PARSER_POINTER_SHIFT;
        bytes32 nextDeref;
        assembly ("memory-safe") {
            nextDeref := mload(nextPointer)
        }
        assertEq(uint256(nextDeref), 0, "list must terminate after first address");
    }

    /// Comments between addresses in a pragma are handled by parseInterstitial.
    function testPragmaKeywordCommentBetweenAddresses() external view {
        address addr1 = 0x1234567890123456789012345678901234567890;
        address addr2 = 0x0987654321098765432109876543210987654321;
        string memory str =
            string.concat("using-words-from ", addr1.toHexString(), " /* a comment */ ", addr2.toHexString());

        address[] memory values = new address[](2);
        values[0] = addr1;
        values[1] = addr2;

        // "using-words-from " (17) + 42 + " /* a comment */ " (17) + 42 = 118
        checkPragmaParsing(str, 118, values, "comment between addresses");
    }

    /// After parseInterstitial advances cursor to end, tryParseLiteral
    /// reads past bounds via mload(cursor). If adjacent memory contains bytes
    /// that look like a valid literal head (e.g., a digit), garbage is parsed
    /// and pushed as a sub-parser address.
    ///
    /// To reproduce: include poison bytes inside the buffer but set end before
    /// them. parseInterstitial consumes the trailing space to reach end, then
    /// tryParseLiteral reads the poison digit '1' at end and dispatches to the
    /// decimal parser, which pushes a garbage sub-parser.
    function testParsePragmaOOBAfterInterstitial() external view {
        // Data includes the real pragma + poison bytes ("1 ") past where end
        // will point. The pragma is 60 bytes: "using-words-from " (17) +
        // 42-char hex address + " " (1 trailing space).
        bytes memory data = bytes("using-words-from 0x1234567890123456789012345678901234567890 1 ");

        ParseState memory state =
            LibParseState.newState(data, "", "", LibAllStandardOps.literalParserFunctionPointers());

        uint256 cursor = Pointer.unwrap(data.dataPointer());
        // Set end to 60: just past the trailing space after the address.
        // The "1 " at positions 60-61 is our poison — in memory but past end.
        uint256 end = cursor + 60;

        uint256 cursorAfter = state.parsePragma(cursor, end);
        (cursorAfter);

        // Verify exactly one sub-parser was pushed (the real address).
        bytes32 deref = state.subParsers;
        assertEq(uint160(uint256(deref)), uint160(0x1234567890123456789012345678901234567890), "real address");
        // The linked list must terminate: no garbage sub-parser was pushed.
        uint256 pointer = uint256(deref) >> SUB_PARSER_POINTER_SHIFT;
        assembly ("memory-safe") {
            deref := mload(pointer)
        }
        assertEq(uint256(deref), 0, "should have only one sub-parser, not garbage from OOB read");
    }

    /// Test a specific string.
    function testPragmaKeywordParseSubParserSpecificStrings() external view {
        string memory str =
            "using-words-from 0x1234567890123456789012345678901234567890 0x1234567890123456789012345678901234567891";
        address[] memory values = new address[](2);
        values[0] = 0x1234567890123456789012345678901234567890;
        values[1] = 0x1234567890123456789012345678901234567891;

        checkPragmaParsing(str, 102, values, "should parse two addresses");

        str = "using-words-from 0x1234567890123456789012345678901234567890 0x1234567890123456789012345678901234567891 ";
        checkPragmaParsing(str, 103, values, "should parse two addresses with trailing whitespace");

        str = "using-words-from 0x1234567890123456789012345678901234567890 0x1234567890123456789012345678901234567891  ";
        checkPragmaParsing(str, 104, values, "should parse two addresses with more trailing whitespace");

        str =
            "using-words-from 0x1234567890123456789012345678901234567890 0x1234567890123456789012345678901234567891  \n";
        checkPragmaParsing(str, 105, values, "should parse two addresses with trailing whitespace and newline");

        str =
            "using-words-from 0x1234567890123456789012345678901234567890 0x1234567890123456789012345678901234567891  \n\n";
        checkPragmaParsing(str, 106, values, "should parse two addresses with trailing whitespace and newlines");

        str = "using-words-from 0x1234567890123456789012345678901234567890";
        values = new address[](1);
        values[0] = 0x1234567890123456789012345678901234567890;
        checkPragmaParsing(str, 59, values, "should parse one address");

        str = "using-words-from 0x1234567890123456789012345678901234567890 ";
        checkPragmaParsing(str, 60, values, "should parse one address with trailing whitespace");

        str = "using-words-from 0x1234567890123456789012345678901234567890  ";
        checkPragmaParsing(str, 61, values, "should parse one address with more trailing whitespace");

        str = "using-words-from 0x1234567890123456789012345678901234567890  \n";
        checkPragmaParsing(str, 62, values, "should parse one address with trailing whitespace and newline");

        str = "using-words-from 0x1234567890123456789012345678901234567890  \n\n";
        checkPragmaParsing(str, 63, values, "should parse one address with trailing whitespace and newlines");

        values = new address[](0);
        str = "using-words-from ";
        checkPragmaParsing(str, 17, values, "should parse no addresses with trailing whitespace");

        str = "using-words-from  ";
        checkPragmaParsing(str, 18, values, "should parse no addresses with more trailing whitespace");

        str = "using-words-from  \n";
        checkPragmaParsing(str, 19, values, "should parse no addresses with trailing whitespace and newline");

        str = "using-words-from  \n\n";
        checkPragmaParsing(str, 20, values, "should parse no addresses with trailing whitespace and newlines");

        str = "";
        checkPragmaParsing(str, 0, values, "should parse no addresses with empty string as noop");

        str = " ";
        checkPragmaParsing(str, 0, values, "should parse no addresses with whitespace as noop");

        str = "using-words-frum ";
        checkPragmaParsing(str, 0, values, "should parse no addresses with typo as noop");
    }
}
