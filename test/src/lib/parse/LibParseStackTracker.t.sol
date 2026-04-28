// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseStackTracker, ParseStackTracker} from "../../../../src/lib/parse/LibParseStackTracker.sol";
import {ParseStackOverflow, ParseStackUnderflow} from "../../../../src/error/ErrParse.sol";

contract LibParseStackTrackerTest is Test {
    using LibParseStackTracker for ParseStackTracker;

    function externalPush(uint256 trackerRaw, uint256 n) external pure returns (uint256) {
        return ParseStackTracker.unwrap(ParseStackTracker.wrap(trackerRaw).push(n));
    }

    function externalPop(uint256 trackerRaw, uint256 n) external pure returns (uint256) {
        return ParseStackTracker.unwrap(ParseStackTracker.wrap(trackerRaw).pop(n));
    }

    function externalPushInputs(uint256 trackerRaw, uint256 n) external pure returns (uint256) {
        return ParseStackTracker.unwrap(ParseStackTracker.wrap(trackerRaw).pushInputs(n));
    }

    /// push reverts with ParseStackOverflow when current + n > 0xFF.
    function testPushOverflow(uint8 current, uint8 n) external {
        vm.assume(uint256(current) + uint256(n) > 0xFF);
        vm.expectRevert(abi.encodeWithSelector(ParseStackOverflow.selector));
        this.externalPush(uint256(current), uint256(n));
    }

    /// push succeeds when current + n <= 0xFF.
    function testPushNoOverflow(uint8 current, uint8 n) external pure {
        vm.assume(uint256(current) + uint256(n) <= 0xFF);
        ParseStackTracker tracker = ParseStackTracker.wrap(uint256(current));
        uint256 result = ParseStackTracker.unwrap(tracker.push(n));
        assertEq(result & 0xFF, uint256(current) + uint256(n));
    }

    /// pop reverts with ParseStackUnderflow when current < n.
    function testPopUnderflow(uint8 current, uint8 n) external {
        vm.assume(uint256(current) < uint256(n));
        vm.expectRevert(abi.encodeWithSelector(ParseStackUnderflow.selector));
        this.externalPop(uint256(current), uint256(n));
    }

    /// pop succeeds when current >= n.
    function testPopNoUnderflow(uint8 current, uint8 n) external pure {
        vm.assume(uint256(current) >= uint256(n));
        ParseStackTracker tracker = ParseStackTracker.wrap(uint256(current));
        uint256 result = ParseStackTracker.unwrap(tracker.pop(n));
        assertEq(result & 0xFF, uint256(current) - uint256(n));
    }

    /// pushInputs reverts with ParseStackOverflow when inputs + n > 0xFF.
    function testPushInputsOverflow(uint8 existingInputs, uint8 n) external {
        vm.assume(uint256(existingInputs) + uint256(n) > 0xFF);
        vm.assume(uint256(n) <= 0xFF);
        vm.expectRevert(abi.encodeWithSelector(ParseStackOverflow.selector));
        this.externalPushInputs(uint256(existingInputs) << 8, uint256(n));
    }

    /// pushInputs succeeds and updates both current and inputs.
    function testPushInputsNoOverflow(uint8 existingInputs, uint8 n) external pure {
        vm.assume(uint256(existingInputs) + uint256(n) <= 0xFF);
        ParseStackTracker tracker = ParseStackTracker.wrap(uint256(existingInputs) << 8);
        uint256 result = ParseStackTracker.unwrap(tracker.pushInputs(n));
        assertEq(result & 0xFF, uint256(n));
        assertEq((result >> 8) & 0xFF, uint256(existingInputs) + uint256(n));
    }

    /// pushInputs reverts with ParseStackOverflow when the internal push
    /// overflows (current + n > 0xFF), before the inputs check is reached.
    function testPushInputsPushOverflow(uint8 current, uint8 n) external {
        vm.assume(uint256(current) + uint256(n) > 0xFF);
        // Inputs byte is 0 so the inputs check would pass — overflow must
        // come from push(n).
        vm.expectRevert(abi.encodeWithSelector(ParseStackOverflow.selector));
        this.externalPushInputs(uint256(current), uint256(n));
    }

    /// push updates high watermark when current + n exceeds previous max.
    function testPushUpdatesHighWatermark(uint8 n) external pure {
        vm.assume(n > 0);
        ParseStackTracker tracker = ParseStackTracker.wrap(0);
        uint256 result = ParseStackTracker.unwrap(tracker.push(n));
        assertEq(result >> 0x10, uint256(n));
    }

    /// push preserves high watermark when current + n does not exceed it.
    function testPushPreservesHighWatermark(uint8 n) external pure {
        vm.assume(n > 0);
        ParseStackTracker tracker = ParseStackTracker.wrap(uint256(0xFF) << 0x10);
        uint256 result = ParseStackTracker.unwrap(tracker.push(n));
        assertEq(result >> 0x10, 0xFF);
    }

    /// push preserves the inputs byte.
    function testPushPreservesInputs(uint8 current, uint8 inputs, uint8 n) external pure {
        vm.assume(uint256(current) + uint256(n) <= 0xFF);
        ParseStackTracker tracker = ParseStackTracker.wrap(uint256(current) | (uint256(inputs) << 8));
        uint256 result = ParseStackTracker.unwrap(tracker.push(n));
        assertEq((result >> 8) & 0xFF, uint256(inputs));
    }

    /// pop preserves inputs and max bytes (direct subtraction invariant).
    function testPopPreservesInputsAndMax(uint8 current, uint8 inputs, uint8 max, uint8 n) external pure {
        vm.assume(uint256(current) >= uint256(n));
        ParseStackTracker tracker =
            ParseStackTracker.wrap(uint256(current) | (uint256(inputs) << 8) | (uint256(max) << 0x10));
        uint256 result = ParseStackTracker.unwrap(tracker.pop(n));
        assertEq((result >> 8) & 0xFF, uint256(inputs));
        assertEq(result >> 0x10, uint256(max));
    }

    /// push with n=0 is a no-op on current and inputs.
    function testPushZero(uint8 current, uint8 inputs, uint8 max) external pure {
        ParseStackTracker tracker =
            ParseStackTracker.wrap(uint256(current) | (uint256(inputs) << 8) | (uint256(max) << 0x10));
        uint256 result = ParseStackTracker.unwrap(tracker.push(0));
        assertEq(result & 0xFF, uint256(current));
        assertEq((result >> 8) & 0xFF, uint256(inputs));
    }

    /// pop with n=0 is a no-op.
    function testPopZero(uint8 current, uint8 inputs, uint8 max) external pure {
        uint256 tracker = uint256(current) | (uint256(inputs) << 8) | (uint256(max) << 0x10);
        uint256 result = ParseStackTracker.unwrap(ParseStackTracker.wrap(tracker).pop(0));
        assertEq(result, tracker);
    }
}
