// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";

/// @title LibParseStatePushConstantValueTest
/// @notice Tests for pushing constant values onto the parse state.
contract LibParseStatePushConstantValueTest is Test {
    using LibParseState for ParseState;

    /// A new state should have an empty constants LL.
    function testPushConstantValueEmpty(
        bytes memory data,
        bytes memory meta,
        bytes memory operandHandlers,
        bytes memory literalParsers
    ) external pure {
        // Start with a fresh state.
        ParseState memory state = LibParseState.newState(data, meta, operandHandlers, literalParsers);

        assertEq(state.constantsBuilder, 0);
        assertEq(state.constantsBloom, 0);
    }

    /// Pushing any value onto an empty constants LL should result in that value
    /// in the state with a pointer to 0.
    function testPushConstantValueSingle(bytes32 value) external pure {
        // Start with a fresh state.
        ParseState memory state = LibParseState.newState("", "", "", "");

        assertEq(state.constantsBuilder, 0);
        assertEq(state.constantsBloom, 0);

        state.pushConstantValue(value);

        // The constants builder low bits should now be 1 as the length of the
        // LL.
        assertEq(state.constantsBuilder & 0xFFFF, 1);

        // The constants builder should now point to the tail.
        uint256 pointer = state.constantsBuilder >> 0x10;
        bytes32 loadedValue;
        bytes32 loadedNext;
        assembly ("memory-safe") {
            loadedValue := mload(add(pointer, 0x20))
            loadedNext := mload(pointer)
        }

        assertEq(loadedValue, value);
        assertEq(loadedNext, 0);
        // The state needs to merge in the constant value bloom.
        assertEq(state.constantsBloom, LibParseState.constantValueBloom(value));
    }

    /// Can push many values to the constants LL.
    function testPushConstantValueMany(bytes32[] memory values) external pure {
        vm.assume(values.length > 0);
        // Start with a fresh state.
        ParseState memory state = LibParseState.newState("", "", "", "");

        assertEq(state.constantsBuilder, 0);
        assertEq(state.constantsBloom, 0);

        for (uint256 i = 0; i < values.length; i++) {
            state.pushConstantValue(values[i]);
        }

        // The constants builder low bits should now be the length of the list
        // of values. The deduping of the values is NOT done by the constant
        // value push, the caller is expected to do that.
        assertEq(state.constantsBuilder & 0xFFFF, values.length);

        // Looping down the pointers should give us the values in reverse order.
        bytes32[] memory loadedFinalValues = new bytes32[](values.length);
        uint256 pointer = state.constantsBuilder >> 0x10;
        uint256 j = loadedFinalValues.length - 1;
        while (pointer != 0) {
            bytes32 loadedValue;
            assembly ("memory-safe") {
                loadedValue := mload(add(pointer, 0x20))
                pointer := mload(pointer)
            }

            loadedFinalValues[j] = loadedValue;

            // This will underflow on the final iteration, which is fine because
            // we don't use it after that.
            unchecked {
                --j;
            }
        }

        for (uint256 k = 0; k < values.length; k++) {
            assertEq(values[k], loadedFinalValues[k]);
            assertTrue(state.constantsBloom & LibParseState.constantValueBloom(values[k]) != 0);
        }
    }
}
