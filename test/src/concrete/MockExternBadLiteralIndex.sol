// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
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
