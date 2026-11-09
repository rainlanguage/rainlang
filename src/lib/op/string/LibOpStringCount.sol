// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Pointer} from "rain-solmem-0.1.28/src/lib/LibPointer.sol";
import {IntOrAString, LibIntOrAString, LENGTH_MASK_V3} from "rain-intorastring-0.1.4/src/lib/LibIntOrAString.sol";
import {OperandV2, StackItem} from "../../../interface/IInterpreterV4.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";

/// @title LibOpStringCount
/// @notice `string-count`: the byte length of an IntOrAString string, as a Float.
library LibOpStringCount {
    using LibIntOrAString for IntOrAString;

    function integrity(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        return (1, 1);
    }

    function run(InterpreterState memory, OperandV2, Pointer stackTop) internal pure returns (Pointer) {
        uint256 lengthMask = LENGTH_MASK_V3;
        assembly ("memory-safe") {
            mstore(stackTop, and(mload(stackTop), lengthMask))
        }
        return stackTop;
    }

    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory)
    {
        StackItem[] memory outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(
            bytes32(bytes(IntOrAString.wrap(uint256(StackItem.unwrap(inputs[0]))).toStringV3()).length)
        );
        return outputs;
    }
}
