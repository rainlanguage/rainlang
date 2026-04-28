// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {LibBytecode} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";

/// @title LibParseInputsOnlyTest
/// @notice Tests that inputs (leading LHS items without RHS items) to an
/// expression are parsed correctly. This test only considers the case where
/// the expression is empty, and the inputs are the entire expression.
/// I.e. the expression is basically an identity function.
contract LibParseInputsOnlyTest is Test {
    using LibParse for ParseState;

    /// Some inputs-only examples. Should produce an empty source.
    /// Test a single input.
    function testParseInputsOnlySingle() external view {
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

    /// Test multiple inputs.
    function testParseInputsOnlyMultiple() external view {
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
}
