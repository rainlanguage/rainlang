// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";

import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";

/// @title LibParseSourceInputsTest
/// @notice Test that inputs to the source (leading LHS items) are handled.
contract LibParseSourceInputsTest is Test {
    using LibParse for ParseState;

    /// A single LHS item is parsed as a source input.
    function testParseSourceInputsSingle() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(":,_:;").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 0 ops
            hex"00"
            // 1 stack allocation
            hex"01"
            // 1 inputs
            hex"01"
            // 1 outputs
            hex"01"
        );
        assertEq(constants.length, 0);
    }

    /// Inputs can appear on the second line, even after an empty line, provided
    /// no RHS items have appeared yet.
    function testParseSourceInputsEmptyLinePrefix() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(":,_:;").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 0 ops
            hex"00"
            // 1 stack allocation
            hex"01"
            // 1 inputs
            hex"01"
            // 1 outputs
            hex"01"
        );
        assertEq(constants.length, 0);
    }

    /// Inputs can be spread across multiple lines, provided no RHS items have
    /// appeared yet. Tests one item per line, two times.
    function testParseSourceInputsMultipleLines() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(":,_:,\n_:;").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 0 ops
            hex"00"
            // 2 stack allocation
            hex"02"
            // 2 inputs
            hex"02"
            // 2 outputs
            hex"02"
        );
        assertEq(constants.length, 0);
    }
}
