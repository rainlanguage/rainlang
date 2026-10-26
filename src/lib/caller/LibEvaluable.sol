// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// Export dispair interfaces for convenience downstream.
// Exported for convenience.
//forge-lint: disable-next-line(unused-import)
import {IInterpreterStoreV3} from "../../interface/IInterpreterStoreV3.sol";

import {EvaluableV4} from "../../interface/IInterpreterCallerV5.sol";

// Number of fixed-size fields (interpreter, store) in `EvaluableV4` before
// the dynamic `bytecode` pointer. 2 fields * 0x20 bytes each = 0x40.
uint256 constant EVALUABLE_V4_FIXED_FIELDS_SIZE = 0x40;

/// @title LibEvaluable
/// @notice Common logic to provide consistent implementations of common tasks
/// that could be arbitrarily/ambiguously implemented, but work much better if
/// consistently implemented.
library LibEvaluable {
    /// Hashes an `EvaluableV4`, ostensibly so that only the hash need be stored,
    /// thus only storing a single `bytes32` instead of 2x `address` and an
    /// arbitrary length `bytes`.
    /// https://github.com/rainlanguage/rain.lib.hash?tab=readme-ov-file#the-pattern
    /// @param evaluable The evaluable to hash.
    /// @return evaluableHash Standard hash of the evaluable.
    function hash(EvaluableV4 memory evaluable) internal pure returns (bytes32) {
        bytes memory bytecode = evaluable.bytecode;
        bytes32 evaluableHash;
        assembly ("memory-safe") {
            // Hash first fields of evaluable (interpreter + store).
            mstore(0, keccak256(evaluable, EVALUABLE_V4_FIXED_FIELDS_SIZE))
            // Hash bytecode.
            mstore(0x20, keccak256(add(bytecode, 0x20), mload(bytecode)))

            // Hash the two hashes.
            evaluableHash := keccak256(0, 0x40)
        }
        return evaluableHash;
    }
}
