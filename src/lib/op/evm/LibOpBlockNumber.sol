// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Pointer} from "rain-solmem-0.1.3/src/lib/LibPointer.sol";
import {OperandV2, StackItem} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {Float, LibDecimalFloat} from "rain-math-float-0.1.1/src/lib/LibDecimalFloat.sol";

/// @title LibOpBlockNumber
/// @notice Implementation of the EVM `BLOCKNUMBER` opcode as a standard Rainlang opcode.
library LibOpBlockNumber {
    using LibDecimalFloat for Float;

    /// @notice `block-number` integrity check. Requires 0 inputs and produces 1 output.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        return (0, 1);
    }

    /// @notice `block-number` opcode. Reads the current block number.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2, Pointer stackTop) internal view returns (Pointer) {
        assembly ("memory-safe") {
            stackTop := sub(stackTop, 0x20)
            mstore(stackTop, number())
        }
        return stackTop;
    }

    /// @notice Reference implementation of `block-number` for testing.
    /// `run()` writes the raw EVM integer directly because
    /// `fromFixedDecimalLosslessPacked(x, 0)` is bitwise-identical to
    /// `bytes32(x)` for any `x` that fits in `int224` — an invariant
    /// owned and tested by `LibDecimalFloat`. The reference path goes
    /// through the float conversion so that fact is explicit at the
    /// opcode boundary.
    /// @return The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory)
        internal
        view
        returns (StackItem[] memory)
    {
        StackItem[] memory outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(Float.unwrap(LibDecimalFloat.fromFixedDecimalLosslessPacked(block.number, 0)));
        return outputs;
    }
}
