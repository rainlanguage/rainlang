// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Pointer} from "rain-solmem-0.1.3/src/lib/LibPointer.sol";
import {OperandV2, StackItem} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {Float} from "rain-math-float-0.1.1/src/lib/LibDecimalFloat.sol";

/// @dev The mathematical constant pi as a `Float`.
/// 3.141592653589793238462643383279502884197169399375105820974944592308e66, -66
Float constant FLOAT_PI =
    Float.wrap(bytes32(uint256(0xffffffbe1dd4c9e873614f593bba9c6007d9a7ac8d03a4b6c700a65cb537a1b4)));

/// @title LibOpPi
/// @notice Stacks the mathematical constant pi.
library LibOpPi {
    /// @notice `pi` integrity check. Requires 0 inputs and produces 1 output.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        return (0, 1);
    }

    /// @notice `pi` opcode. Pushes the mathematical constant pi onto the stack.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2, Pointer stackTop) internal pure returns (Pointer) {
        Float pi = FLOAT_PI;
        assembly ("memory-safe") {
            stackTop := sub(stackTop, 0x20)
            mstore(stackTop, pi)
        }
        return stackTop;
    }

    /// @notice Reference implementation of `pi` for testing.
    /// @return The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory)
        internal
        pure
        returns (StackItem[] memory)
    {
        StackItem[] memory outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(Float.unwrap(FLOAT_PI));
        return outputs;
    }
}
