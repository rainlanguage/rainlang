// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {AuthoringMetaV2} from "rain.interpreter.interface/interface/IParserV2.sol";
import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {OperandV2, LibParseOperand} from "../../../../src/lib/parse/LibParseOperand.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibConvert} from "rain.lib.typecast/LibConvert.sol";
import {LibAllStandardOps} from "../../../../src/lib/op/LibAllStandardOps.sol";
import {LibGenParseMeta} from "rain.interpreter.interface/lib/codegen/LibGenParseMeta.sol";

/// @title LibParseSingleRHSNamedGasTest
/// @notice Parse a single RHS name for many different sized RHS names just to include
/// the gas cost of the name lookup in the gas snapshot.
contract LibParseSingleRHSNamedGasTest is Test {
    using LibParse for ParseState;

    function parseMeta() internal pure returns (bytes memory) {
        AuthoringMetaV2[] memory authoringMeta = new AuthoringMetaV2[](32);
        authoringMeta[0] = AuthoringMetaV2("a", "a");
        authoringMeta[1] = AuthoringMetaV2("aa", "aa");
        authoringMeta[2] = AuthoringMetaV2("aaa", "aaa");
        authoringMeta[3] = AuthoringMetaV2("aaaa", "aaaa");
        authoringMeta[4] = AuthoringMetaV2("aaaaa", "aaaaa");
        authoringMeta[5] = AuthoringMetaV2("aaaaaa", "aaaaaa");
        authoringMeta[6] = AuthoringMetaV2("aaaaaaa", "aaaaaaa");
        authoringMeta[7] = AuthoringMetaV2("aaaaaaaa", "aaaaaaaa");
        authoringMeta[8] = AuthoringMetaV2("aaaaaaaaa", "aaaaaaaaa");
        authoringMeta[9] = AuthoringMetaV2("aaaaaaaaaa", "aaaaaaaaaa");
        authoringMeta[10] = AuthoringMetaV2("aaaaaaaaaaa", "aaaaaaaaaaa");
        authoringMeta[11] = AuthoringMetaV2("aaaaaaaaaaaa", "aaaaaaaaaaaa");
        authoringMeta[12] = AuthoringMetaV2("aaaaaaaaaaaaa", "aaaaaaaaaaaaa");
        authoringMeta[13] = AuthoringMetaV2("aaaaaaaaaaaaaa", "aaaaaaaaaaaaaa");
        authoringMeta[14] = AuthoringMetaV2("aaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaa");
        authoringMeta[15] = AuthoringMetaV2("aaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaa");
        authoringMeta[16] = AuthoringMetaV2("aaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaa");
        authoringMeta[17] = AuthoringMetaV2("aaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaa");
        authoringMeta[18] = AuthoringMetaV2("aaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaa");
        authoringMeta[19] = AuthoringMetaV2("aaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaa");
        authoringMeta[20] = AuthoringMetaV2("aaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaa");
        authoringMeta[21] = AuthoringMetaV2("aaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaa");
        authoringMeta[22] = AuthoringMetaV2("aaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaa");
        authoringMeta[23] = AuthoringMetaV2("aaaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaaa");
        authoringMeta[24] = AuthoringMetaV2("aaaaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaaaa");
        authoringMeta[25] = AuthoringMetaV2("aaaaaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaaaaa");
        authoringMeta[26] = AuthoringMetaV2("aaaaaaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaaaaaa");
        authoringMeta[27] = AuthoringMetaV2("aaaaaaaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaaaaaaa");
        authoringMeta[28] = AuthoringMetaV2("aaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
        authoringMeta[29] = AuthoringMetaV2("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
        authoringMeta[30] = AuthoringMetaV2("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
        authoringMeta[31] = AuthoringMetaV2("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");

        return LibGenParseMeta.buildParseMetaV2(authoringMeta, 2);
    }

    function operandHandlers() internal pure returns (bytes memory) {
        function(bytes32[] memory) internal pure returns (OperandV2)[] memory handlers =
            new function(bytes32[] memory) internal pure returns (OperandV2)[](32);
        handlers[0] = LibParseOperand.handleOperandDisallowed;
        handlers[1] = LibParseOperand.handleOperandDisallowed;
        handlers[2] = LibParseOperand.handleOperandDisallowed;
        handlers[3] = LibParseOperand.handleOperandDisallowed;
        handlers[4] = LibParseOperand.handleOperandDisallowed;
        handlers[5] = LibParseOperand.handleOperandDisallowed;
        handlers[6] = LibParseOperand.handleOperandDisallowed;
        handlers[7] = LibParseOperand.handleOperandDisallowed;
        handlers[8] = LibParseOperand.handleOperandDisallowed;
        handlers[9] = LibParseOperand.handleOperandDisallowed;
        handlers[10] = LibParseOperand.handleOperandDisallowed;
        handlers[11] = LibParseOperand.handleOperandDisallowed;
        handlers[12] = LibParseOperand.handleOperandDisallowed;
        handlers[13] = LibParseOperand.handleOperandDisallowed;
        handlers[14] = LibParseOperand.handleOperandDisallowed;
        handlers[15] = LibParseOperand.handleOperandDisallowed;
        handlers[16] = LibParseOperand.handleOperandDisallowed;
        handlers[17] = LibParseOperand.handleOperandDisallowed;
        handlers[18] = LibParseOperand.handleOperandDisallowed;
        handlers[19] = LibParseOperand.handleOperandDisallowed;
        handlers[20] = LibParseOperand.handleOperandDisallowed;
        handlers[21] = LibParseOperand.handleOperandDisallowed;
        handlers[22] = LibParseOperand.handleOperandDisallowed;
        handlers[23] = LibParseOperand.handleOperandDisallowed;
        handlers[24] = LibParseOperand.handleOperandDisallowed;
        handlers[25] = LibParseOperand.handleOperandDisallowed;
        handlers[26] = LibParseOperand.handleOperandDisallowed;
        handlers[27] = LibParseOperand.handleOperandDisallowed;
        handlers[28] = LibParseOperand.handleOperandDisallowed;
        handlers[29] = LibParseOperand.handleOperandDisallowed;
        handlers[30] = LibParseOperand.handleOperandDisallowed;
        handlers[31] = LibParseOperand.handleOperandDisallowed;
        uint256[] memory pointers;
        assembly ("memory-safe") {
            pointers := handlers
        }
        return LibConvert.unsafeTo16BitBytes(pointers);
    }

    function newState(string memory source) internal pure returns (ParseState memory) {
        return LibParseState.newState(
            bytes(source), parseMeta(), operandHandlers(), LibAllStandardOps.literalParserFunctionPointers()
        );
    }

    /// Test parsing "a" (1 char) as the RHS.
    function testParseGasRHS00() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:a();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aa" (2 chars) as the RHS.
    function testParseGasRHS01() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaa" (3 chars) as the RHS.
    function testParseGasRHS02() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaa" (4 chars) as the RHS.
    function testParseGasRHS03() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaa" (5 chars) as the RHS.
    function testParseGasRHS04() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaa" (6 chars) as the RHS.
    function testParseGasRHS05() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaa" (7 chars) as the RHS.
    function testParseGasRHS06() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaa" (8 chars) as the RHS.
    function testParseGasRHS07() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaa" (9 chars) as the RHS.
    function testParseGasRHS08() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaa" (10 chars) as the RHS.
    function testParseGasRHS09() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaa" (11 chars) as the RHS.
    function testParseGasRHS10() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaaa" (12 chars) as the RHS.
    function testParseGasRHS11() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaaaa" (13 chars) as the RHS.
    function testParseGasRHS12() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaaaaa" (14 chars) as the RHS.
    function testParseGasRHS13() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaaaaaa" (15 chars) as the RHS.
    function testParseGasRHS14() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaaaaaaa" (16 chars) as the RHS.
    function testParseGasRHS15() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaaaaaaaa" (17 chars) as the RHS.
    function testParseGasRHS16() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaa" (18 chars) as the RHS.
    function testParseGasRHS17() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaa" (19 chars) as the RHS.
    function testParseGasRHS18() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaa" (20 chars) as the RHS.
    function testParseGasRHS19() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaa" (21 chars) as the RHS.
    function testParseGasRHS20() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaaaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaaa" (22 chars) as the RHS.
    function testParseGasRHS21() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaaaaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaaaa" (23 chars) as the RHS.
    function testParseGasRHS22() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaaaaaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaaaaa" (24 chars) as the RHS.
    function testParseGasRHS23() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaaaaaaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaaaaaa" (25 chars) as the RHS.
    function testParseGasRHS24() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaaaaaaaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaaaaaaa" (26 chars) as the RHS.
    function testParseGasRHS25() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaaaaaaaaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaaaaaaaa" (27 chars) as the RHS.
    function testParseGasRHS26() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaaaaaaaaaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaaaaaaaaa" (28 chars) as the RHS.
    function testParseGasRHS27() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaaaaaaaaaaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaaaaaaaaaa" (29 chars) as the RHS.
    function testParseGasRHS28() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaaaaaaaaaaaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" (30 chars) as the RHS.
    function testParseGasRHS29() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }

    /// Test parsing "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" (31 chars) as the RHS.
    function testParseGasRHS30() external view {
        (bytes memory bytecode, bytes32[] memory constants) = newState("_:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa();").parse();
        (bytecode);
        (constants);
    }
}
