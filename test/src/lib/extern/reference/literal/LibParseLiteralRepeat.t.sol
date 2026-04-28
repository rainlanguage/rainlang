// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {
    LibParseLiteralRepeat,
    RepeatDispatchNotDigit,
    RepeatLiteralTooLong
} from "../../../../../../src/lib/extern/reference/literal/LibParseLiteralRepeat.sol";

contract LibParseLiteralRepeatTest is Test {
    /// External wrapper for parseRepeat so that expectRevert can catch
    /// the revert at a deeper call depth.
    function externalParseRepeat(uint256 dispatchValue, uint256 cursor, uint256 end) external pure returns (uint256) {
        return LibParseLiteralRepeat.parseRepeat(dispatchValue, cursor, end);
    }

    /// Fuzz the output value of parseRepeat against a reference sum.
    function testParseRepeatOutputValueFuzz(uint256 dispatchValue, uint256 length) external pure {
        dispatchValue = bound(dispatchValue, 0, 9);
        length = bound(length, 0, 77);
        uint256 value = LibParseLiteralRepeat.parseRepeat(dispatchValue, 0, length);
        uint256 expected = 0;
        for (uint256 i = 0; i < length; i++) {
            expected += dispatchValue * 10 ** i;
        }
        assertEq(value, expected);
    }

    /// Dispatch value 10 must revert.
    function testParseRepeatInvalidDispatch() external {
        vm.expectRevert(abi.encodeWithSelector(RepeatDispatchNotDigit.selector, uint256(10)));
        this.externalParseRepeat(10, 0, 3);
    }

    /// Any dispatch value > 9 must revert.
    function testParseRepeatInvalidDispatchFuzz(uint256 dispatchValue) external {
        vm.assume(dispatchValue > 9);
        vm.expectRevert(abi.encodeWithSelector(RepeatDispatchNotDigit.selector, dispatchValue));
        this.externalParseRepeat(dispatchValue, 0, 3);
    }

    /// A literal body of length >= 78 must revert with RepeatLiteralTooLong.
    function testParseRepeatTooLong(uint256 length) external {
        length = bound(length, 78, 1000);
        vm.expectRevert(abi.encodeWithSelector(RepeatLiteralTooLong.selector, length));
        this.externalParseRepeat(1, 0, length);
    }
}
