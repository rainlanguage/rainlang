// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {IntegrityCheckState} from "../../../integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../../state/LibInterpreterState.sol";
import {NotAnAddress} from "../../../../error/ErrRainType.sol";

/// @title LibOpUint256ERC721BalanceOf
/// @notice Opcode for getting the current erc721 balance of an account.
library LibOpUint256ERC721BalanceOf {
    /// @notice `uint256-erc721-balance-of` integrity check. Requires 2 inputs
    /// and produces 1 output.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        // Always 2 inputs, the token and the account.
        // Always 1 output, the balance.
        return (2, 1);
    }

    /// @notice `uint256-erc721-balance-of` opcode. Calls `balanceOf` on the token and returns the raw uint256 balance.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2, Pointer stackTop) internal view returns (Pointer) {
        uint256 token;
        uint256 account;
        assembly ("memory-safe") {
            token := mload(stackTop)
            stackTop := add(stackTop, 0x20)
            account := mload(stackTop)
        }
        // Casting to `uint160` is intentional to detect non-address values.
        //forge-lint: disable-next-line(unsafe-typecast)
        if (token != uint256(uint160(token))) revert NotAnAddress(token);
        // Casting to `uint160` is intentional to detect non-address values.
        //forge-lint: disable-next-line(unsafe-typecast)
        if (account != uint256(uint160(account))) revert NotAnAddress(account);
        // Casting to `uint160` is safe because `NotAnAddress` above
        // ensures the value fits in 160 bits.
        //forge-lint: disable-next-line(unsafe-typecast)
        uint256 tokenBalance = IERC721(address(uint160(token))).balanceOf(address(uint160(account)));
        assembly ("memory-safe") {
            mstore(stackTop, tokenBalance)
        }
        return stackTop;
    }

    /// @notice Reference implementation of `uint256-erc721-balance-of` for testing.
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
        uint256 accountValue = uint256(StackItem.unwrap(inputs[1]));
        // Casting to `uint160` is intentional to detect non-address values.
        //forge-lint: disable-next-line(unsafe-typecast)
        if (accountValue != uint256(uint160(accountValue))) revert NotAnAddress(accountValue);
        // Casting to `uint160` is safe because `NotAnAddress` above
        // ensures the value fits in 160 bits.
        //forge-lint: disable-next-line(unsafe-typecast)
        address token = address(uint160(tokenValue));
        //forge-lint: disable-next-line(unsafe-typecast)
        address account = address(uint160(accountValue));
        uint256 tokenBalance = IERC721(token).balanceOf(account);
        StackItem[] memory outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(bytes32(tokenBalance));
        return outputs;
    }
}
