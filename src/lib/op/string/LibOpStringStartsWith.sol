// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Pointer} from "rain-solmem-0.1.28/src/lib/LibPointer.sol";
import {IntOrAString, LibIntOrAString, LENGTH_MASK_V3} from "rain-intorastring-0.1.4/src/lib/LibIntOrAString.sol";
import {OperandV2, StackItem} from "../../../interface/IInterpreterV4.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";

/// @title LibOpStringStartsWith
/// @notice `string-starts-with`: 1 if the first string starts with the second, else 0.
library LibOpStringStartsWith {
    using LibIntOrAString for IntOrAString;

    function integrity(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        return (2, 1);
    }

    function run(InterpreterState memory, OperandV2, Pointer stackTop) internal pure returns (Pointer) {
        uint256 lengthMask = LENGTH_MASK_V3;
        assembly ("memory-safe") {
            let s := mload(stackTop)
            let p := mload(add(stackTop, 0x20))
            let sLength := and(s, lengthMask)
            let pLength := and(p, lengthMask)
            let sLeft := shl(sub(256, mul(8, sLength)), shr(8, s))
            let pLeft := shl(sub(256, mul(8, pLength)), shr(8, p))
            let shift := sub(256, mul(8, pLength))
            stackTop := add(stackTop, 0x20)
            mstore(stackTop, and(iszero(gt(pLength, sLength)), eq(shr(shift, sLeft), shr(shift, pLeft))))
        }
        return stackTop;
    }

    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory)
    {
        bytes memory s = bytes(IntOrAString.wrap(uint256(StackItem.unwrap(inputs[0]))).toStringV3());
        bytes memory p = bytes(IntOrAString.wrap(uint256(StackItem.unwrap(inputs[1]))).toStringV3());
        bool startsWith = p.length <= s.length;
        for (uint256 i = 0; startsWith && i < p.length; i++) {
            startsWith = s[i] == p[i];
        }
        StackItem[] memory outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(bytes32(uint256(startsWith ? 1 : 0)));
        return outputs;
    }
}
