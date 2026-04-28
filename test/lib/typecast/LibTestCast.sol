// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

/// @title LibTestCast
/// @notice Type casts for test code. These are zero-cost reinterpretations
/// between types that share identical memory layouts.
library LibTestCast {
    /// @notice Casts a `StackItem[]` to `bytes32[]`. Both types have identical
    /// memory layouts so this is a zero-cost reinterpretation.
    /// @param items The stack items array.
    /// @return b32s The same array reinterpreted as `bytes32[]`.
    function asBytes32Array(StackItem[] memory items) internal pure returns (bytes32[] memory b32s) {
        assembly ("memory-safe") {
            b32s := items
        }
    }
}
