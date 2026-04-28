// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {IntegrityCheckState} from "../../../integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../../state/LibInterpreterState.sol";
import {NotAnAddress} from "../../../../error/ErrRainType.sol";

/// @title LibOpUint256ERC20Allowance
/// @notice Opcode for getting the current erc20 allowance of an account.
library LibOpUint256ERC20Allowance {
    /// @notice `uint256-erc20-allowance` integrity check. Requires 3 inputs
    /// and produces 1 output.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        // Always 3 inputs, the token, the owner and the spender.
        // Always 1 output, the allowance.
        return (3, 1);
    }

    /// @notice `uint256-erc20-allowance` opcode. Calls `allowance` on the token and returns the raw uint256 allowance.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2, Pointer stackTop) internal view returns (Pointer) {
        uint256 token;
        uint256 owner;
        uint256 spender;
        assembly ("memory-safe") {
            token := mload(stackTop)
            owner := mload(add(stackTop, 0x20))
            stackTop := add(stackTop, 0x40)
            spender := mload(stackTop)
        }
        // It is the rainlang author's responsibility to ensure the correctness
        // of token, owner, and spender as addresses.
        // Casting to `uint160` is intentional to detect non-address values.
        //forge-lint: disable-next-line(unsafe-typecast)
        if (token != uint256(uint160(token))) revert NotAnAddress(token);
        // Casting to `uint160` is intentional to detect non-address values.
        //forge-lint: disable-next-line(unsafe-typecast)
        if (owner != uint256(uint160(owner))) revert NotAnAddress(owner);
        // Casting to `uint160` is intentional to detect non-address values.
        //forge-lint: disable-next-line(unsafe-typecast)
        if (spender != uint256(uint160(spender))) revert NotAnAddress(spender);
        uint256 tokenAllowance =
        // Casting to `uint160` is safe because `NotAnAddress` above
        // ensures the value fits in 160 bits.
        //forge-lint: disable-next-line(unsafe-typecast)
        IERC20(address(uint160(token))).allowance(address(uint160(owner)), address(uint160(spender)));
        assembly ("memory-safe") {
            mstore(stackTop, tokenAllowance)
        }
        return stackTop;
    }

    /// @notice Reference implementation of `uint256-erc20-allowance` for testing.
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
        uint256 ownerValue = uint256(StackItem.unwrap(inputs[1]));
        // Casting to `uint160` is intentional to detect non-address values.
        //forge-lint: disable-next-line(unsafe-typecast)
        if (ownerValue != uint256(uint160(ownerValue))) revert NotAnAddress(ownerValue);
        uint256 spenderValue = uint256(StackItem.unwrap(inputs[2]));
        // Casting to `uint160` is intentional to detect non-address values.
        //forge-lint: disable-next-line(unsafe-typecast)
        if (spenderValue != uint256(uint160(spenderValue))) revert NotAnAddress(spenderValue);
        // Casting to `uint160` is safe because `NotAnAddress` above
        // ensures the value fits in 160 bits.
        //forge-lint: disable-next-line(unsafe-typecast)
        address token = address(uint160(tokenValue));
        // Casting to `uint160` is safe because `NotAnAddress` above
        // ensures the value fits in 160 bits.
        //forge-lint: disable-next-line(unsafe-typecast)
        address owner = address(uint160(ownerValue));
        // Casting to `uint160` is safe because `NotAnAddress` above
        // ensures the value fits in 160 bits.
        //forge-lint: disable-next-line(unsafe-typecast)
        address spender = address(uint160(spenderValue));
        uint256 tokenAllowance = IERC20(token).allowance(owner, spender);
        StackItem[] memory outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(bytes32(tokenAllowance));
        return outputs;
    }
}
