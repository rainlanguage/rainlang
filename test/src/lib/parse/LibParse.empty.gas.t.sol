// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";

/// @title LibParseEmptyGasTest
/// @notice Exercise a few different sized empty expressions to get a gas snapshot of the
/// parsing cost.
contract LibParseEmptyGasTest is Test {
    using LibParse for ParseState;

    /// Test parsing "" (0 chars) an empty expression.
    function testParseGasEmpty00() external view {
        LibMetaFixture.newState("").parse();
    }

    /// Test parsing ":;" (2 chars) an empty expression.
    function testParseGasEmpty01() external view {
        LibMetaFixture.newState(":;").parse();
    }

    /// Test parsing ":;:;" (4 chars) an empty expression.
    function testParseGasEmpty02() external view {
        LibMetaFixture.newState(":;:;").parse();
    }

    /// Test parsing ":;:;:;" (6 chars) an empty expression.
    function testParseGasEmpty03() external view {
        LibMetaFixture.newState(":;:;:;").parse();
    }

    /// Test parsing ":;:;:;:;" (8 chars) an empty expression.
    function testParseGasEmpty04() external view {
        LibMetaFixture.newState(":;:;:;:;").parse();
    }
}
