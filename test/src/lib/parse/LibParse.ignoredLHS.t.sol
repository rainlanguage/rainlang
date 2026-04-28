// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";

import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {LibBytecode} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";

/// @title LibParseIgnoredLHSTest
/// @notice Tests parsing ignored LHS items. An ignored LHS item is one that starts with
/// an underscore and is cheaper than named LHS items as they don't need to be
/// tracked for potential use in the RHS.
contract LibParseIgnoredLHSTest is Test {
    using LibParse for ParseState;

    /// A lone underscore should parse to an empty source and constant.
    function testParseIgnoredLHSLoneUnderscore() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_:;").parse();
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 1);
        assertEq(outputs, 1);
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
            // 1 input
            hex"01"
            // 1 output
            hex"01"
        );
        assertEq(constants.length, 0);
    }

    /// Two underscores should parse to an empty source and constant.
    function testParseIgnoredLHSTwoUnderscores() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_ _:;").parse();
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 2);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 2);
        assertEq(outputs, 2);
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

    /// Inputs can be on multiple lines if there are no RHS items.
    function testParseIgnoredLHSMultipleLines() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_:,_ _:;").parse();
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 3);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 3);
        assertEq(outputs, 3);
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 0 ops
            hex"00"
            // 3 stack allocation
            hex"03"
            // 3 inputs
            hex"03"
            // 3 outputs
            hex"03"
        );

        assertEq(constants.length, 0);
    }

    /// An underscore that is NOT an input should parse to a non-empty source
    /// with no constants.
    function testParseIgnoredLHSUnderscoreNotInput() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(":,_:a();").parse();
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 1);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 0);
        assertEq(outputs, 1);
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 ops
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 output
            hex"01"
            // a
            hex"02100000"
        );

        assertEq(constants.length, 0);
    }

    /// An underscore followed by some alpha chars should parse to an empty
    /// source and constant.
    function testParseIgnoredLHSUnderscoreAlpha() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_a:;").parse();
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 1);
        assertEq(outputs, 1);
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
            // 1 input
            hex"01"
            // 1 output
            hex"01"
        );
        assertEq(constants.length, 0);
    }

    /// Two ignored alphas should parse to an empty source and constant.
    function testParseIgnoredLHSTwoAlphas() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_a _b:;").parse();
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 2);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 2);
        assertEq(outputs, 2);
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

    // Ignored alphas can be multiple chars long each.
    function testParseIgnoredLHSAlphaTooLong() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_foo _bar:;").parse();
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 2);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 2);
        assertEq(outputs, 2);
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
            // 2 output
            hex"02"
        );
        assertEq(constants.length, 0);
    }

    /// Ignored words have no size limit. We can parse a 32 char ignored word.
    /// Normally words are limited to 31 chars.
    function testParseIgnoredWordTooLong() external view {
        (bytes memory bytecode, bytes32[] memory constants) =
            LibMetaFixture.newState("_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:;").parse();
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 1);
        assertEq(outputs, 1);
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
            // 1 input
            hex"01"
            // 1 output
            hex"01"
        );
        assertEq(constants.length, 0);
    }
}
