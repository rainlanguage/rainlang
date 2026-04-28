// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibBytes, Pointer} from "rain.solmem/lib/LibBytes.sol";
import {LibParseState, ParseState} from "../../src/lib/parse/LibParseState.sol";
import {LibParseLiteral, UnsupportedLiteralType} from "../../src/lib/parse/literal/LibParseLiteral.sol";
import {LibAllStandardOps} from "../../src/lib/op/LibAllStandardOps.sol";

contract ParseLiteralTest is Test {
    using LibBytes for bytes;
    using LibParseLiteral for ParseState;

    function checkUnsupportedLiteralType(bytes memory data, uint256 offset) internal {
        ParseState memory state =
            LibParseState.newState(data, "", "", LibAllStandardOps.literalParserFunctionPointers());
        state.literalParsers = LibAllStandardOps.literalParserFunctionPointers();
        uint256 outerStart = Pointer.unwrap(data.dataPointer());
        uint256 cursor = outerStart;
        uint256 end = outerStart + data.length;
        vm.expectRevert(abi.encodeWithSelector(UnsupportedLiteralType.selector, offset));
        bytes32 value;
        (cursor, value) = state.parseLiteral(cursor, end);
        (cursor, value);
    }

    function checkLiteralBounds(
        function(ParseState memory, uint256, uint256) pure returns (uint256, uint256, uint256) bounder,
        bytes memory data,
        uint256 expectedInnerStart,
        uint256 expectedInnerEnd,
        uint256 expectedOuterEnd,
        uint256 expectedFinalCursor
    ) internal pure {
        uint256 cursor = Pointer.unwrap(data.dataPointer());
        uint256 end = cursor + data.length;

        (uint256 innerStart, uint256 innerEnd, uint256 outerEnd) =
            bounder(LibParseState.newState(data, "", "", ""), cursor, end);
        assertEq(innerStart, cursor + expectedInnerStart, "innerStart");
        assertEq(innerEnd, cursor + expectedInnerEnd, "innerEnd");
        assertEq(outerEnd, cursor + expectedOuterEnd, "outerEnd");
        assertEq(outerEnd - cursor, expectedFinalCursor, "finalCursor");
    }
}
