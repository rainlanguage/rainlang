// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {Float, LibDecimalFloat} from "rain.math.float/lib/LibDecimalFloat.sol";
import {LibDecimalFloatImplementation} from "rain.math.float/lib/implementation/LibDecimalFloatImplementation.sol";

/// @title LibOpDiv
/// @notice Opcode to div N decimal float values. Errors on overflow.
library LibOpDiv {
    using LibDecimalFloat for Float;

    /// @notice `div` integrity check. Requires at least 2 inputs and produces 1 output.
    /// @param operand Low 4 bits of the high byte encode the input count.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2 operand) internal pure returns (uint256, uint256) {
        // There must be at least two inputs.
        uint256 inputs = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;
        inputs = inputs > 1 ? inputs : 2;
        return (inputs, 1);
    }

    /// @notice div
    /// decimal floating point division.
    /// @param operand Low 4 bits of the high byte encode the input count.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2 operand, Pointer stackTop) internal pure returns (Pointer) {
        Float a;
        Float b;
        assembly ("memory-safe") {
            a := mload(stackTop)
            b := mload(add(stackTop, 0x20))
            stackTop := add(stackTop, 0x40)
        }
        (int256 signedCoefficient, int256 exponent) = a.unpack();
        (int256 signedCoefficientB, int256 exponentB) = b.unpack();
        (signedCoefficient, exponent) =
            LibDecimalFloatImplementation.div(signedCoefficient, exponent, signedCoefficientB, exponentB);

        {
            uint256 inputs = uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F;
            uint256 i = 2;
            while (i < inputs) {
                assembly ("memory-safe") {
                    b := mload(stackTop)
                    stackTop := add(stackTop, 0x20)
                }
                (signedCoefficientB, exponentB) = b.unpack();
                (signedCoefficient, exponent) =
                    LibDecimalFloatImplementation.div(signedCoefficient, exponent, signedCoefficientB, exponentB);
                unchecked {
                    i++;
                }
            }
        }
        //slither-disable-next-line unused-return
        (a,) = LibDecimalFloat.packLossy(signedCoefficient, exponent);
        assembly ("memory-safe") {
            stackTop := sub(stackTop, 0x20)
            mstore(stackTop, a)
        }
        return stackTop;
    }

    /// @notice Gas intensive reference implementation of division for testing.
    /// @param inputs The input values from the stack.
    /// @return outputs The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        pure
        returns (StackItem[] memory outputs)
    {
        // Unchecked so that when we assert that an overflow error is thrown, we
        // see the revert from the real function and not the reference function.
        unchecked {
            Float a = Float.wrap(StackItem.unwrap(inputs[0]));
            (int256 signedCoefficient, int256 exponent) = a.unpack();
            for (uint256 i = 1; i < inputs.length; i++) {
                Float b = Float.wrap(StackItem.unwrap(inputs[i]));
                // Just bail out with a = some sentinel value if we're going to
                // overflow or divide by zero. This gives the real implementation
                // space to throw its own error that the test harness is expecting.
                // We don't want the real implementation to fail to throw the
                // error and also produce the same result, so a needs to have
                // some collision resistant value.
                if (b.isZero()) {
                    a = Float.wrap(bytes32(keccak256(abi.encodePacked("overflow sentinel"))));
                    break;
                }
                (int256 signedCoefficientB, int256 exponentB) = b.unpack();
                (signedCoefficient, exponent) =
                    LibDecimalFloatImplementation.div(signedCoefficient, exponent, signedCoefficientB, exponentB);
            }
            bool lossless;
            (a, lossless) = LibDecimalFloat.packLossy(signedCoefficient, exponent);
            (lossless);
            outputs = new StackItem[](1);
            outputs[0] = StackItem.wrap(Float.unwrap(a));
        }
    }
}
