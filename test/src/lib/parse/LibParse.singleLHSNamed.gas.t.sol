// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibParse} from "../../../../src/lib/parse/LibParse.sol";

/// @title LibParseSingleLHSNamedGasTest
/// @notice Parse a single named LHS for many different sized LHS names just to include
/// the gas cost of the parsing in the gas snapshot.
contract LibParseSingleLHSNamedGasTest is Test {
    using LibParse for ParseState;

    function newState(string memory s) internal pure returns (ParseState memory) {
        return LibParseState.newState(
            bytes(s),
            "",
            // There's no operands on the LHS.
            "",
            // There's no literals on the LHS.
            ""
        );
    }

    /// Test parsing "a" (1 char) a named LHS item.
    function testParseGasSingleLHSNamed00() external view {
        newState("a:;").parse();
    }

    /// Test parsing "aa" (2 chars) a named LHS item.
    function testParseGasSingleLHSNamed01() external view {
        newState("aa:;").parse();
    }

    /// Test parsing "aaa" (3 chars) a named LHS item.
    function testParseGasSingleLHSNamed02() external view {
        newState("aaa:;").parse();
    }

    /// Test parsing "aaaa" (4 chars) a named LHS item.
    function testParseGasSingleLHSNamed03() external view {
        newState("aaaa:;").parse();
    }

    /// Test parsing "aaaaa" (5 chars) a named LHS item.
    function testParseGasSingleLHSNamed04() external view {
        newState("aaaaa:;").parse();
    }

    /// Test parsing "aaaaaa" (6 chars) a named LHS item.
    function testParseGasSingleLHSNamed05() external view {
        newState("aaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaa" (7 chars) a named LHS item.
    function testParseGasSingleLHSNamed06() external view {
        newState("aaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaa" (8 chars) a named LHS item.
    function testParseGasSingleLHSNamed07() external view {
        newState("aaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaa" (9 chars) a named LHS item.
    function testParseGasSingleLHSNamed08() external view {
        newState("aaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaa" (10 chars) a named LHS item.
    function testParseGasSingleLHSNamed09() external view {
        newState("aaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaa" (11 chars) a named LHS item.
    function testParseGasSingleLHSNamed10() external view {
        newState("aaaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaaa" (12 chars) a named LHS item.
    function testParseGasSingleLHSNamed11() external view {
        newState("aaaaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaaaa" (13 chars) a named LHS item.
    function testParseGasSingleLHSNamed12() external view {
        newState("aaaaaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaaaaa" (14 chars) a named LHS item.
    function testParseGasSingleLHSNamed13() external view {
        newState("aaaaaaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaaaaaa" (15 chars) a named LHS item.
    function testParseGasSingleLHSNamed14() external view {
        newState("aaaaaaaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaaaaaaa" (16 chars) a named LHS item.
    function testParseGasSingleLHSNamed15() external view {
        newState("aaaaaaaaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaaaaaaaa" (17 chars) a named LHS item.
    function testParseGasSingleLHSNamed16() external view {
        newState("aaaaaaaaaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaa" (18 chars) a named LHS item.
    function testParseGasSingleLHSNamed17() external view {
        newState("aaaaaaaaaaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaa" (19 chars) a named LHS item.
    function testParseGasSingleLHSNamed18() external view {
        newState("aaaaaaaaaaaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaa" (20 chars) a named LHS item.
    function testParseGasSingleLHSNamed19() external view {
        newState("aaaaaaaaaaaaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaa" (21 chars) a named LHS item.
    function testParseGasSingleLHSNamed20() external view {
        newState("aaaaaaaaaaaaaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaaa" (22 chars) a named LHS item.
    function testParseGasSingleLHSNamed21() external view {
        newState("aaaaaaaaaaaaaaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaaaa" (23 chars) a named LHS item.
    function testParseGasSingleLHSNamed22() external view {
        newState("aaaaaaaaaaaaaaaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaaaaa" (24 chars) a named LHS item.
    function testParseGasSingleLHSNamed23() external view {
        newState("aaaaaaaaaaaaaaaaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaaaaaa" (25 chars) a named LHS item.
    function testParseGasSingleLHSNamed24() external view {
        newState("aaaaaaaaaaaaaaaaaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaaaaaaa" (26 chars) a named LHS item.
    function testParseGasSingleLHSNamed25() external view {
        newState("aaaaaaaaaaaaaaaaaaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaaaaaaaa" (27 chars) a named LHS item.
    function testParseGasSingleLHSNamed26() external view {
        newState("aaaaaaaaaaaaaaaaaaaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaaaaaaaaa" (28 chars) a named LHS item.
    function testParseGasSingleLHSNamed27() external view {
        newState("aaaaaaaaaaaaaaaaaaaaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaaaaaaaaaa" (29 chars) a named LHS item.
    function testParseGasSingleLHSNamed28() external view {
        newState("aaaaaaaaaaaaaaaaaaaaaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" (30 chars) a named LHS item.
    function testParseGasSingleLHSNamed29() external view {
        newState("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:;").parse();
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" (31 chars) a named LHS item.
    function testParseGasSingleLHSNamed30() external view {
        newState("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:;").parse();
    }
}
