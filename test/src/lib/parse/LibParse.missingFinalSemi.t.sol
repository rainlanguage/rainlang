// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ParseTest} from "test/abstract/ParseTest.sol";
import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {MissingFinalSemi} from "../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";

/// @title LibParseMissingFinalSemiTest
/// @notice Tests that missing final semicolons are rejected. Every expression
/// MUST end with a semicolon as the EOF character.
contract LibParseMissingFinalSemiTest is ParseTest {
    using LibParse for ParseState;

    /// A lone colon should revert as missing a semi.
    function testParseMissingFinalSemiRevertsLoneColon() external {
        vm.expectRevert(abi.encodeWithSelector(MissingFinalSemi.selector, LibParseError.tagErrorOffset(1)));
        this.parseExternal(":");
    }

    /// A lone colon after an empty source should error as missing a semi.
    function testParseMissingFinalSemiRevertsEmptySource() external {
        vm.expectRevert(abi.encodeWithSelector(MissingFinalSemi.selector, LibParseError.tagErrorOffset(3)));
        this.parseExternal(":;:");
    }

    /// An empty source with a trailing comma should error as missing a semi.
    function testParseMissingFinalSemiRevertsTrailingComma() external {
        vm.expectRevert(abi.encodeWithSelector(MissingFinalSemi.selector, LibParseError.tagErrorOffset(2)));
        this.parseExternal(":,");
    }

    /// A single word without a trailing semi should error as missing a semi.
    function testParseMissingFinalSemiRevertsSingleWord() external {
        vm.expectRevert(abi.encodeWithSelector(MissingFinalSemi.selector, LibParseError.tagErrorOffset(4)));
        this.parseExternal(":a()");
    }

    /// Some detached LHS items should error as missing a semi.
    function testParseMissingFinalSemiRevertsLHSItems() external {
        vm.expectRevert(abi.encodeWithSelector(MissingFinalSemi.selector, LibParseError.tagErrorOffset(3)));
        this.parseExternal("_ _");
    }
}
