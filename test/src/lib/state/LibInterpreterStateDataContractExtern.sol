// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {LibInterpreterStateDataContract} from "../../../../src/lib/state/LibInterpreterStateDataContract.sol";
import {InterpreterState} from "../../../../src/lib/state/LibInterpreterState.sol";
import {Pointer} from "rain-solmem-0.1.3/src/lib/LibPointer.sol";
import {FullyQualifiedNamespace} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterV4.sol";
import {IInterpreterStoreV3} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterStoreV3.sol";

/// @dev Wraps unsafeDeserialize as an external call to avoid
/// stack-too-deep from inlining the 9-field struct return.
contract LibInterpreterStateDataContractExtern {
    function deserialize(
        bytes memory serialized,
        uint256 sourceIndex,
        FullyQualifiedNamespace namespace,
        IInterpreterStoreV3 store,
        bytes32[][] memory context,
        bytes memory fs
    ) external pure returns (InterpreterState memory) {
        return LibInterpreterStateDataContract.unsafeDeserialize(serialized, sourceIndex, namespace, store, context, fs);
    }

    /// Deserializes and reads each stack's allocated length from memory.
    /// Must run inside the same call context as deserialization so that
    /// the stack pointers reference live memory.
    function deserializeStackLengths(bytes memory serialized) external pure returns (uint256[] memory) {
        InterpreterState memory state = LibInterpreterStateDataContract.unsafeDeserialize(
            serialized, 0, FullyQualifiedNamespace.wrap(0), IInterpreterStoreV3(address(0)), new bytes32[][](0), ""
        );
        uint256 count = state.stackBottoms.length;
        uint256[] memory lengths = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            Pointer bottom = state.stackBottoms[i];
            uint256 len;
            assembly ("memory-safe") {
                // Scan backwards from bottom for the array length word.
                // Stack layout is [length][slot0]...[slotN-1], bottom
                // points past slotN-1. At offset (length+1) words back
                // from bottom, mload == length.
                for { let offset := 2 } 1 { offset := add(offset, 1) } {
                    let v := mload(sub(bottom, mul(offset, 0x20)))
                    if eq(add(v, 1), offset) {
                        len := v
                        break
                    }
                }
            }
            lengths[i] = len;
        }
        return lengths;
    }
}
