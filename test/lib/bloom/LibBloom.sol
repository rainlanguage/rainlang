//// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

library LibBloom {
    /// Returns true if any of the words are duplicates according to a bloom filter.
    /// The bloom filter is 1024 bits.
    function bloomFindsDupes(bytes32[] memory words) internal pure returns (bool dupes) {
        assembly ("memory-safe") {
            let bloom0 := 0
            let bloom1 := 0
            let bloom2 := 0
            let bloom3 := 0
            let shifted0 := 0
            let shifted1 := 0
            let shifted2 := 0
            let shifted3 := 0
            let cursor := add(words, 0x20)
            let end := add(cursor, mul(mload(words), 0x20))

            for {} lt(cursor, end) { cursor := add(cursor, 0x20) } {
                {
                    mstore(0, mload(cursor))
                    let hashed0 := keccak256(0, 0x20)
                    shifted0 := shl(and(hashed0, 0xFF), 1)
                    mstore(0, hashed0)
                    let hashed1 := keccak256(0, 0x20)
                    shifted1 := shl(and(hashed1, 0xFF), 1)
                    mstore(0, hashed1)
                    let hashed2 := keccak256(0, 0x20)
                    shifted2 := shl(and(hashed2, 0xFF), 1)
                    mstore(0, hashed2)
                    let hashed3 := keccak256(0, 0x20)
                    shifted3 := shl(and(hashed3, 0xFF), 1)
                }

                let match :=
                    and(
                        and(iszero(iszero(and(bloom0, shifted0))), iszero(iszero(and(bloom1, shifted1)))),
                        and(iszero(iszero(and(bloom2, shifted2))), iszero(iszero(and(bloom3, shifted3))))
                    )

                if iszero(iszero(match)) {
                    dupes := 1
                    break
                }

                bloom0 := or(bloom0, shifted0)
                bloom1 := or(bloom1, shifted1)
                bloom2 := or(bloom2, shifted2)
                bloom3 := or(bloom3, shifted3)
            }
        }
    }

    /// Overloaded version of bloomFindsDupes that takes `uint256[]`.
    function bloomFindsDupes(uint256[] memory us) internal pure returns (bool) {
        bytes32[] memory kvs;
        assembly ("memory-safe") {
            kvs := us
        }
        return bloomFindsDupes(kvs);
    }
}
