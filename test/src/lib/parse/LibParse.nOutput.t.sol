// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ParseTest} from "test/abstract/ParseTest.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";

import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {LibBytecode} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";
import {ExcessLHSItems, ExcessRHSItems} from "../../../../src/error/ErrParse.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";

/// @title LibParseNOutputTest
/// @notice Test that the parser can handle multi and zero outputs for RHS items when
/// they are singular on a line, and mandates individual items otherwise.
contract LibParseNOutputTest is ParseTest {
    using LibParse for ParseState;

    /// A single RHS item MAY have 0 outputs.
    function testParseNOutputExcessRHS0() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(":a();").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 ops
            hex"01"
            // 0 stack allocation
            hex"00"
            // 0 input
            hex"00"
            // 0 outputs
            hex"00"
            // a
            hex"02000000"
        );
        assertEq(constants.length, 0);
    }

    /// Multiple RHS items MUST NOT have 0 outputs. Tests two RHS items and zero
    /// LHS items.
    function testParseNOutputExcessRHS1() external {
        vm.expectRevert(abi.encodeWithSelector(ExcessRHSItems.selector, LibParseError.tagErrorOffset(8)));
        this.parseExternal(":a() b();");
    }

    /// Multiple RHS items MUST NOT have 0 outputs. Tests two RHS items and one
    /// LHS item.
    function testParseNOutputExcessRHS2() external {
        vm.expectRevert(abi.encodeWithSelector(ExcessRHSItems.selector, LibParseError.tagErrorOffset(9)));
        this.parseExternal("_:a() b();");
    }

    /// A single RHS item can have multiple outputs. This RHS item has nesting.
    /// Nested words are always treated as a single output.
    function testParseNOutputNestedRHS() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(":,_ _:a(b());").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 2 ops
            hex"02"
            // 2 stack allocation
            hex"02"
            // 0 inputs
            hex"00"
            // 2 outputs
            hex"02"
            // b 1 output
            hex"03100000"
            // a 1 input
            hex"02210000"
        );
        assertEq(constants.length, 0);
    }

    /// Multiple RHS items MUST NOT have multiple outputs. Tests two RHS items
    /// and three LHS items.
    function testParseNOutputExcessRHS3() external {
        vm.expectRevert(abi.encodeWithSelector(ExcessLHSItems.selector, LibParseError.tagErrorOffset(13)));
        this.parseExternal("_ _ _:a() b();");
    }

    /// Multiple output RHS items MAY be followed by single output RHS items,
    /// on a new line.
    function testParseBalanceStackOffsetsInputs() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("_ _:a(), _:b();").parse();
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(constants.length, 0);
        // a and b should be parsed and inputs are just ignored in the output
        // source.
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 2 ops
            hex"02"
            // 3 stack allocation
            hex"03"
            // 0 inputs
            hex"00"
            // 3 outputs
            hex"03"
            // a
            hex"02200000"
            // b
            hex"03100000"
        );

        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 2);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 3);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 0);
        assertEq(outputs, 3);
    }
}
