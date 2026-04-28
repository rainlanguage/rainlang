// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {InterpreterState} from "../../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../../integrity/LibIntegrityCheck.sol";
import {Float, LibDecimalFloat} from "rain.math.float/lib/LibDecimalFloat.sol";

/// @title LibOpLinearGrowth
/// @notice Linear growth is base + rate * t where base is the initial value, rate is
/// the growth rate, and t is time.
library LibOpLinearGrowth {
    using LibDecimalFloat for Float;

    /// @notice `linear-growth` integrity check. Requires exactly 3 inputs and produces 1 output.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        // There must be three inputs and one output.
        return (3, 1);
    }

    /// @notice linear-growth
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2, Pointer stackTop) internal pure returns (Pointer) {
        Float base;
        Float rate;
        Float t;
        assembly ("memory-safe") {
            base := mload(stackTop)
            rate := mload(add(stackTop, 0x20))
            stackTop := add(stackTop, 0x40)
            t := mload(stackTop)
        }

        base = base.add(rate.mul(t));

        assembly ("memory-safe") {
            mstore(stackTop, base)
        }
        return stackTop;
    }

    /// @notice Gas intensive reference implementation for testing.
    /// @param inputs The input values from the stack.
    /// @return The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory)
    {
        Float base = Float.wrap(StackItem.unwrap(inputs[0]));
        Float rate = Float.wrap(StackItem.unwrap(inputs[1]));
        Float t = Float.wrap(StackItem.unwrap(inputs[2]));
        StackItem[] memory outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(Float.unwrap(base.add(rate.mul(t))));
        return outputs;
    }
}
