// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";

/// @title LibParseInputsOnlyGasTest
/// @notice Exercise a few different sized inputs-only expressions to get a gas
/// snapshot of the parsing cost.
contract LibParseInputsOnlyGasTest is Test {
    using LibParse for ParseState;

    /// Test parsing "_:;" (3 chars) an inputs-only expression.
    function testParseGasInputsOnly00() external view {
        LibMetaFixture.newState("_:;").parse();
    }

    /// Test parsing "_ _:;" (5 chars) an inputs-only expression.
    function testParseGasInputsOnly01() external view {
        LibMetaFixture.newState("_ _:;").parse();
    }

    /// Test parsing "_ _ _:;" (7 chars) an inputs-only expression.
    function testParseGasInputsOnly02() external view {
        LibMetaFixture.newState("_ _ _:;").parse();
    }

    /// Test parsing "_ _ _ _:;" (9 chars) an inputs-only expression.
    function testParseGasInputsOnly03() external view {
        LibMetaFixture.newState("_ _ _ _:;").parse();
    }

    /// Test parsing "_ _ _ _ _:;" (11 chars) an inputs-only expression.
    function testParseGasInputsOnly04() external view {
        LibMetaFixture.newState("_ _ _ _ _:;").parse();
    }

    /// Test parsing "_ _ _ _ _ _:;" (13 chars) an inputs-only expression.
    function testParseGasInputsOnly05() external view {
        LibMetaFixture.newState("_ _ _ _ _ _:;").parse();
    }

    /// Test parsing "_ _ _ _ _ _ _:;" (15 chars) an inputs-only expression.
    function testParseGasInputsOnly06() external view {
        LibMetaFixture.newState("_ _ _ _ _ _ _:;").parse();
    }

    /// Test parsing "_ _ _ _ _ _ _ _:;" (17 chars) an inputs-only expression.
    function testParseGasInputsOnly07() external view {
        LibMetaFixture.newState("_ _ _ _ _ _ _ _:;").parse();
    }

    /// Test parsing "_ _ _ _ _ _ _ _ _:;" (19 chars) an inputs-only expression.
    function testParseGasInputsOnly08() external view {
        LibMetaFixture.newState("_ _ _ _ _ _ _ _ _:;").parse();
    }

    /// Test parsing "_ _ _ _ _ _ _ _ _ _:;" (21 chars) an inputs-only expression.
    function testParseGasInputsOnly09() external view {
        LibMetaFixture.newState("_ _ _ _ _ _ _ _ _ _:;").parse();
    }
}
