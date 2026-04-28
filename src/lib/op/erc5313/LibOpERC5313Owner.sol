// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {IERC5313} from "openzeppelin-contracts/contracts/interfaces/IERC5313.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {IntegrityCheckState} from "../../integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../state/LibInterpreterState.sol";
import {NotAnAddress} from "../../../error/ErrRainType.sol";

/// @title LibOpERC5313Owner
/// @notice Opcode for ERC5313 `owner`.
library LibOpERC5313Owner {
    /// @notice `erc5313-owner` integrity check. Requires 1 input and produces 1 output.
    /// @return The number of inputs.
    /// @return The number of outputs.
    function integrity(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        // Always 1 input, the contract.
        // Always 1 output, the owner.
        return (1, 1);
    }

    /// @notice `erc5313-owner` opcode. Calls `owner()` on the given contract address.
    /// @param stackTop Pointer to the top of the stack.
    /// @return The new stack top pointer after execution.
    function run(InterpreterState memory, OperandV2, Pointer stackTop) internal view returns (Pointer) {
        uint256 account;
        assembly ("memory-safe") {
            account := mload(stackTop)
        }
        // It is the rainlang author's responsibility to ensure the correctness
        // of account as an address.
        // Casting to `uint160` is intentional to detect non-address values.
        //forge-lint: disable-next-line(unsafe-typecast)
        if (account != uint256(uint160(account))) revert NotAnAddress(account);
        // Casting to `uint160` is safe because `NotAnAddress` above
        // ensures the value fits in 160 bits.
        //forge-lint: disable-next-line(unsafe-typecast)
        address owner = IERC5313(address(uint160(account))).owner();
        assembly ("memory-safe") {
            mstore(stackTop, owner)
        }
        return stackTop;
    }

    /// @notice Reference implementation of `erc5313-owner` for testing.
    /// @param inputs The input values from the stack.
    /// @return The output values to push onto the stack.
    function referenceFn(InterpreterState memory, OperandV2, StackItem[] memory inputs)
        internal
        view
        returns (StackItem[] memory)
    {
        uint256 accountValue = uint256(StackItem.unwrap(inputs[0]));
        // Casting to `uint160` is intentional to detect non-address values.
        //forge-lint: disable-next-line(unsafe-typecast)
        if (accountValue != uint256(uint160(accountValue))) revert NotAnAddress(accountValue);
        // Casting to `uint160` is safe because `NotAnAddress` above
        // ensures the value fits in 160 bits.
        //forge-lint: disable-next-line(unsafe-typecast)
        address owner = IERC5313(address(uint160(accountValue))).owner();
        StackItem[] memory outputs = new StackItem[](1);
        outputs[0] = StackItem.wrap(bytes32(uint256(uint160(owner))));
        return outputs;
    }
}
