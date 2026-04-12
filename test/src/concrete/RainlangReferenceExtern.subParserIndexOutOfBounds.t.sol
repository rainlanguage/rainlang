// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {RainlangReferenceExtern} from "../../../src/concrete/extern/RainlangReferenceExtern.sol";
import {SubParserIndexOutOfBounds} from "../../../src/error/ErrSubParse.sol";

/// @dev Mock subclass that forces matchSubParseLiteralDispatch to return an
/// out-of-bounds index, triggering the SubParserIndexOutOfBounds check.
contract MockExternBadLiteralIndex is RainlangReferenceExtern {
    /// @notice Override to always return success with an out-of-bounds index.
    function matchSubParseLiteralDispatch(uint256, uint256) internal pure override returns (bool, uint256, bytes32) {
        return (true, 999, bytes32(0));
    }
}

/// @title RainlangReferenceExternSubParserIndexOutOfBoundsTest
/// @notice Test that `SubParserIndexOutOfBounds` reverts when an
/// out-of-bounds index is returned from the literal dispatch lookup.
contract RainlangReferenceExternSubParserIndexOutOfBoundsTest is Test {
    /// @notice Calling subParseLiteral2 on a mock that returns an out-of-bounds
    /// literal parser index must revert with SubParserIndexOutOfBounds.
    function testSubParseLiteral2IndexOutOfBounds() external {
        MockExternBadLiteralIndex ext = new MockExternBadLiteralIndex();

        bytes memory data = abi.encodePacked(uint16(4), bytes4(0x01020304), bytes4(0x05060708));

        vm.expectRevert(abi.encodeWithSelector(SubParserIndexOutOfBounds.selector, uint256(999), uint256(1)));
        ext.subParseLiteral2(data);
    }
}
