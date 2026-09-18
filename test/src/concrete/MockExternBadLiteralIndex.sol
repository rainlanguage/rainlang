// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainlangReferenceExtern} from "../../../src/concrete/extern/RainlangReferenceExtern.sol";

/// @dev Mock subclass that forces matchSubParseLiteralDispatch to return an
/// out-of-bounds index, triggering the SubParserIndexOutOfBounds check.
contract MockExternBadLiteralIndex is RainlangReferenceExtern {
    /// @notice Override to always return success with an out-of-bounds index.
    function matchSubParseLiteralDispatch(uint256, uint256) internal pure override returns (bool, uint256, bytes32) {
        return (true, 999, bytes32(0));
    }
}
