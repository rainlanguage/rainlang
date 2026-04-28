// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {LibParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibCtPop} from "rain.math.binary/lib/LibCtPop.sol";

/// @title LibParseStateConstantValueBloomTest
/// @notice Tests for the constant value bloom filter in LibParseState.
contract LibParseStateConstantValueBloomTest is Test {
    /// This is a kinda pointless test, it just duplicates the internal logic...
    function testConstantValueBloom(bytes32 value) external pure {
        assertEq(LibParseState.constantValueBloom(value), bytes32(uint256(1) << (uint256(value) % 256)));
    }

    /// Exactly one bit should be set for any value.
    function testConstantValueBloomSingleBit(bytes32 value) external pure {
        assertEq(LibCtPop.ctpop(uint256(LibParseState.constantValueBloom(value))), uint256(1));
    }

    /// All bits should be set over 256 values.
    function testConstantValueBloomAllBits() external pure {
        uint256 bloom = 0;
        for (uint256 i = 0; i < 256; i++) {
            bloom |= uint256(LibParseState.constantValueBloom(bytes32(i)));
        }
        assertEq(bloom, type(uint256).max);
    }
}
