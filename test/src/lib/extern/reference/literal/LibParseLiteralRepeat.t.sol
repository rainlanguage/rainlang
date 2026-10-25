// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {LibDecimalFloat, Float} from "rain-math-float-0.3.10/src/lib/LibDecimalFloat.sol";
import {LossyConversionToFloat} from "rain-math-float-0.3.10/src/error/ErrDecimalFloat.sol";
import {SafeCast} from "@openzeppelin-contracts-5.7.0/utils/math/SafeCast.sol";

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

    function repeatSum(uint256 dispatchValue, uint256 length) internal pure returns (uint256) {
        uint256 expected = 0;
        for (uint256 i = 0; i < length; i++) {
            expected += dispatchValue * 10 ** i;
        }
        return expected;
    }

    /// Bodies whose repeated value fits the Float coefficient parse to that
    /// value at exponent 0.
    function testParseRepeatInRangeBodyKeepsValue(uint256 dispatchValue, uint256 length) external pure {
        dispatchValue = bound(dispatchValue, 0, 9);
        length = bound(length, 0, 67);
        uint256 value = LibParseLiteralRepeat.parseRepeat(dispatchValue, 0, length);
        (int256 coefficient, int256 exponent) = LibDecimalFloat.unpack(Float.wrap(bytes32(value)));
        assertEq(coefficient, int256(repeatSum(dispatchValue, length)));
        assertEq(exponent, 0);
    }

    /// Repeating 0 is 0 at every allowed length.
    function testParseRepeatZeroIsZeroAtAnyLength() external pure {
        for (uint256 length = 0; length < 78; length++) {
            assertEq(LibParseLiteralRepeat.parseRepeat(0, 0, length), 0);
        }
    }

    /// Every non-zero body whose repeated value exceeds the Float coefficient
    /// reverts instead of spilling into the exponent.
    function testParseRepeatOverflowingBodyReverts() external {
        for (uint256 dispatchValue = 1; dispatchValue <= 9; dispatchValue++) {
            for (uint256 length = 68; length < 78; length++) {
                uint256 expected = repeatSum(dispatchValue, length);
                if (expected > uint256(type(int256).max)) {
                    vm.expectRevert(abi.encodeWithSelector(SafeCast.SafeCastOverflowedUintToInt.selector, expected));
                } else {
                    vm.expectRevert(abi.encodeWithSelector(LossyConversionToFloat.selector, int256(expected), 0));
                }
                this.externalParseRepeat(dispatchValue, 0, length);
            }
        }
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
