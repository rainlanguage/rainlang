// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseOperand, OperandV2} from "../../../../src/lib/parse/LibParseOperand.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibAllStandardOps} from "../../../../src/lib/op/LibAllStandardOps.sol";
import {UnexpectedOperand, ExpectedOperand} from "../../../../src/error/ErrParse.sol";

/// @title LibParseOperandHandleOperandTest
/// @notice Direct unit tests for the `handleOperand` dispatch function.
contract LibParseOperandHandleOperandTest is Test {
    using LibParseOperand for ParseState;

    function handleOperandExternal(ParseState memory state, uint256 wordIndex) external pure returns (OperandV2) {
        return state.handleOperand(wordIndex);
    }

    /// Both handleOperandSingleFull (index 1, stack) and
    /// handleOperandDisallowed (index 4, bitwise-and) return 0 for empty
    /// operand values.
    function testHandleOperandDispatchEmptyValues() external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");
        state.operandHandlers = LibAllStandardOps.operandHandlerFunctionPointers();
        state.operandValues = new bytes32[](0);

        // Index 1 (stack) -> handleOperandSingleFull -> returns 0.
        assertEq(OperandV2.unwrap(state.handleOperand(1)), 0, "stack empty");
        // Index 4 (bitwise-and) -> handleOperandDisallowed -> returns 0.
        assertEq(OperandV2.unwrap(state.handleOperand(4)), 0, "bitwise-and empty");
    }

    /// Prove different indices dispatch to different handlers: index 1 (stack,
    /// handleOperandSingleFull) accepts a single value and returns it;
    /// index 4 (bitwise-and, handleOperandDisallowed) reverts.
    function testHandleOperandDispatchDifferentHandlers(uint256 value) external {
        value = bound(value, 0, type(uint16).max);
        ParseState memory state = LibParseState.newState("", "", "", "");
        state.operandHandlers = LibAllStandardOps.operandHandlerFunctionPointers();

        bytes32[] memory values = new bytes32[](1);
        values[0] = bytes32(value);
        state.operandValues = values;

        // Index 1 (stack) -> handleOperandSingleFull -> returns the value.
        assertEq(OperandV2.unwrap(state.handleOperand(1)), bytes32(value), "stack single value");

        // Index 4 (bitwise-and) -> handleOperandDisallowed -> reverts.
        vm.expectRevert(abi.encodeWithSelector(UnexpectedOperand.selector));
        this.handleOperandExternal(state, 4);
    }

    /// Multiple indices that share the same handler produce the same result.
    /// Indices 1 (stack) and 2 (constant) both use handleOperandSingleFull.
    function testHandleOperandDispatchSameHandler(uint256 value) external pure {
        value = bound(value, 0, type(uint16).max);
        ParseState memory state = LibParseState.newState("", "", "", "");
        state.operandHandlers = LibAllStandardOps.operandHandlerFunctionPointers();

        bytes32[] memory values = new bytes32[](1);
        values[0] = bytes32(value);
        state.operandValues = values;

        bytes32 expected = bytes32(value);
        assertEq(OperandV2.unwrap(state.handleOperand(1)), expected, "stack");
        assertEq(OperandV2.unwrap(state.handleOperand(2)), expected, "constant");
    }

    /// Multiple indices that use handleOperandDisallowed all revert when
    /// given a value.
    function testHandleOperandDispatchDisallowedMultipleIndices() external {
        ParseState memory state = LibParseState.newState("", "", "", "");
        state.operandHandlers = LibAllStandardOps.operandHandlerFunctionPointers();

        bytes32[] memory values = new bytes32[](1);
        values[0] = bytes32(uint256(1));
        state.operandValues = values;

        // Index 4 (bitwise-and), 8 (bitwise-or), 12 (hash) all use
        // handleOperandDisallowed.
        vm.expectRevert(abi.encodeWithSelector(UnexpectedOperand.selector));
        this.handleOperandExternal(state, 4);

        vm.expectRevert(abi.encodeWithSelector(UnexpectedOperand.selector));
        this.handleOperandExternal(state, 8);

        vm.expectRevert(abi.encodeWithSelector(UnexpectedOperand.selector));
        this.handleOperandExternal(state, 12);
    }
}
