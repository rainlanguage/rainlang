// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";
import {LibTOFUTokenDecimals} from "rain.tofu.erc20-decimals/lib/LibTOFUTokenDecimals.sol";
import {NotAnAddress} from "../../../error/ErrRainType.sol";

/// @title LibOpERC20TotalSupply
/// @notice Opcode for ERC20 `totalSupply`.
library LibOpERC20TotalSupply {
    /// @notice `erc20-total-supply` integrity check. Requires 1 input and produces 1 output.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        // Always 1 input, the contract.
        // Always 1 output, the total supply.
        return (1, 1);
    }

    /// @notice `erc20-total-supply` opcode. Calls `totalSupply` on the token and converts the result to a decimal float using the token's `decimals`.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2, Pointer stackTop) internal view returns (Pointer) {
        uint256 token;
        assembly ("memory-safe") {
            token := mload(stackTop)
        }
        // It is the rainlang author's responsibility to ensure the correctness
        // of token as an address.
        // Casting to `uint160` is intentional to detect non-address values.
        //forge-lint: disable-next-line(unsafe-typecast)
        if (token != uint256(uint160(token))) revert NotAnAddress(token);
        // Casting to `uint160` is safe because `NotAnAddress` above
        // ensures the value fits in 160 bits.
        //forge-lint: disable-next-line(unsafe-typecast)
        uint256 totalSupply = IERC20(address(uint160(token))).totalSupply();

        // Casting to `uint160` is safe because `NotAnAddress` above
        // ensures the value fits in 160 bits.
        //forge-lint: disable-next-line(unsafe-typecast)
        uint8 tokenDecimals = LibTOFUTokenDecimals.safeDecimalsForTokenReadOnly(address(uint160(token)));

        Float totalSupplyFloat = LibDecimalFloat.fromFixedDecimalLosslessPacked(totalSupply, tokenDecimals);

        assembly ("memory-safe") {
            mstore(stackTop, totalSupplyFloat)
        }
        return stackTop;
    }

    /// @notice Reference implementation of `erc20-total-supply` for testing.
    /// @param inputs The input values from the stack.
    /// @return The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        view
        returns (StackItem[] memory)
    {
        uint256 tokenValue = uint256(StackItem.unwrap(inputs[0]));
        // Casting to `uint160` is intentional to detect non-address values.
        //forge-lint: disable-next-line(unsafe-typecast)
        if (tokenValue != uint256(uint160(tokenValue))) revert NotAnAddress(tokenValue);
        // Casting to `uint160` is safe because `NotAnAddress` above
        // ensures the value fits in 160 bits.
        //forge-lint: disable-next-line(unsafe-typecast)
        address token = address(uint160(tokenValue));
        uint256 totalSupply = IERC20(token).totalSupply();

        uint8 tokenDecimals = LibTOFUTokenDecimals.safeDecimalsForTokenReadOnly(token);
        Float totalSupplyFloat = LibDecimalFloat.fromFixedDecimalLosslessPacked(totalSupply, tokenDecimals);

        StackItem[] memory outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(Float.unwrap(totalSupplyFloat));
        return outputs;
    }
}
