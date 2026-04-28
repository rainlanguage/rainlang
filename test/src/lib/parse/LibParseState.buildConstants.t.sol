// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";

/// @title LibParseStateBuildConstantsTest
/// @notice Direct unit tests for buildConstants.
contract LibParseStateBuildConstantsTest is Test {
    using LibParseState for ParseState;

    /// Empty constants list produces a zero-length array.
    function testBuildConstantsEmpty() external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");
        bytes32[] memory constants = state.buildConstants();
        assertEq(constants.length, 0, "empty constants length");
    }

    /// Single constant is returned correctly.
    function testBuildConstantsSingle(bytes32 value) external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");
        state.pushConstantValue(value);
        bytes32[] memory constants = state.buildConstants();
        assertEq(constants.length, 1, "single constants length");
        assertEq(constants[0], value, "single constant value");
    }

    /// Multiple constants are returned in push order (reversed from linked
    /// list traversal order).
    function testBuildConstantsMultiple() external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");
        state.pushConstantValue(bytes32(uint256(0xaa)));
        state.pushConstantValue(bytes32(uint256(0xbb)));
        state.pushConstantValue(bytes32(uint256(0xcc)));

        bytes32[] memory constants = state.buildConstants();
        assertEq(constants.length, 3, "length");
        assertEq(constants[0], bytes32(uint256(0xaa)), "first");
        assertEq(constants[1], bytes32(uint256(0xbb)), "second");
        assertEq(constants[2], bytes32(uint256(0xcc)), "third");
    }

    /// Fuzz: push N constants, verify buildConstants returns them in push
    /// order.
    function testBuildConstantsFuzz(bytes32[] memory values) external pure {
        vm.assume(values.length > 0 && values.length <= 100);
        ParseState memory state = LibParseState.newState("", "", "", "");

        for (uint256 i = 0; i < values.length; i++) {
            state.pushConstantValue(values[i]);
        }

        bytes32[] memory constants = state.buildConstants();
        assertEq(constants.length, values.length, "length mismatch");
        for (uint256 i = 0; i < values.length; i++) {
            assertEq(constants[i], values[i], "value mismatch");
        }
    }
}
