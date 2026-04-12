// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";

import {OperandV2} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {
    IInterpreterExternV4,
    ExternDispatchV2,
    StackItem
} from "rain.interpreter.interface/interface/IInterpreterExternV4.sol";
import {IIntegrityToolingV1} from "rain.sol.codegen/interface/IIntegrityToolingV1.sol";
import {IOpcodeToolingV1} from "rain.sol.codegen/interface/IOpcodeToolingV1.sol";
import {ExternOpcodeOutOfRange, ExternPointersMismatch, ExternOpcodePointersEmpty} from "../error/ErrExtern.sol";

/// @dev Empty opcode function pointers constant. Inheriting contracts should
/// create their own constant and override `opcodeFunctionPointers` to use
/// theirs.
bytes constant OPCODE_FUNCTION_POINTERS = hex"";
/// @dev Empty integrity function pointers constant. Inheriting contracts should
/// create their own constant and override `integrityFunctionPointers` to use
/// theirs.
bytes constant INTEGRITY_FUNCTION_POINTERS = hex"";

/// Base implementation of `IInterpreterExternV4`. Inherit from this contract,
/// and override `opcodeFunctionPointers` and `integrityFunctionPointers` to
/// provide lists of function pointers.
abstract contract BaseRainlangExtern is IInterpreterExternV4, IIntegrityToolingV1, IOpcodeToolingV1, ERC165 {
    /// Validates that opcode function pointers are non-empty and that opcode
    /// and integrity function pointer tables have the same length. This ensures
    /// every opcode has a corresponding integrity check, and that the mod in
    /// `extern()` cannot divide by zero.
    constructor() {
        uint256 opcodeFunctionPointersLength = opcodeFunctionPointers().length;
        if (opcodeFunctionPointersLength == 0) {
            revert ExternOpcodePointersEmpty();
        }
        uint256 integrityFunctionPointersLength = integrityFunctionPointers().length;
        if (opcodeFunctionPointersLength != integrityFunctionPointersLength) {
            revert ExternPointersMismatch(opcodeFunctionPointersLength, integrityFunctionPointersLength);
        }
    }

    /// @inheritdoc IInterpreterExternV4
    function extern(ExternDispatchV2 dispatch, StackItem[] memory inputs)
        external
        view
        virtual
        override
        returns (StackItem[] memory outputs)
    {
        unchecked {
            bytes memory fPointers = opcodeFunctionPointers();
            // We mod the opcode with the function pointer count to ensure
            // that the index is always in bounds. A mod is cheaper than a
            // bounds check, and mirrors how the main eval loop handles
            // opcode dispatch. This protects against malicious callers
            // passing an out-of-range opcode, since `extern` is `external`
            // and can be called directly by anyone. Without the mod, an
            // out-of-range opcode reads arbitrary memory and interprets it
            // as a function pointer, allowing a jump to arbitrary code.
            // The integrity check (`externIntegrity`) separately protects
            // against accidental out-of-bounds opcodes by reverting at
            // parse time.
            uint256 fsCount = fPointers.length / 2;
            uint256 fPointersStart;
            assembly ("memory-safe") {
                fPointersStart := add(fPointers, 0x20)
            }
            uint256 opcode = uint256((ExternDispatchV2.unwrap(dispatch) >> 0x10) & bytes32(uint256(type(uint16).max)));
            OperandV2 operand = OperandV2.wrap(ExternDispatchV2.unwrap(dispatch) & bytes32(uint256(type(uint16).max)));

            function(OperandV2, StackItem[] memory) internal view returns (StackItem[] memory) f;
            assembly ("memory-safe") {
                f := shr(0xf0, mload(add(fPointersStart, mul(mod(opcode, fsCount), 2))))
            }
            outputs = f(operand, inputs);
        }
    }

    /// @inheritdoc IInterpreterExternV4
    function externIntegrity(ExternDispatchV2 dispatch, uint256 expectedInputs, uint256 expectedOutputs)
        external
        pure
        virtual
        override
        returns (uint256 actualInputs, uint256 actualOutputs)
    {
        unchecked {
            bytes memory fPointers = integrityFunctionPointers();
            uint256 fsCount = fPointers.length / 2;
            uint256 fPointersStart;
            assembly ("memory-safe") {
                fPointersStart := add(fPointers, 0x20)
            }
            uint256 opcode = uint256((ExternDispatchV2.unwrap(dispatch) >> 0x10) & bytes32(uint256(type(uint16).max)));
            if (opcode >= fsCount) {
                revert ExternOpcodeOutOfRange(opcode, fsCount);
            }
            OperandV2 operand = OperandV2.wrap(ExternDispatchV2.unwrap(dispatch) & bytes32(uint256(type(uint16).max)));

            function(OperandV2, uint256, uint256) internal pure returns (uint256, uint256) f;
            assembly ("memory-safe") {
                f := shr(0xf0, mload(add(fPointersStart, mul(opcode, 2))))
            }
            (actualInputs, actualOutputs) = f(operand, expectedInputs, expectedOutputs);
        }
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return type(IInterpreterExternV4).interfaceId == interfaceId
            || type(IIntegrityToolingV1).interfaceId == interfaceId || type(IOpcodeToolingV1).interfaceId == interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @notice Overrideable function to provide the list of function pointers
    /// for opcode dispatches.
    //slither-disable-next-line dead-code
    function opcodeFunctionPointers() internal view virtual returns (bytes memory) {
        return OPCODE_FUNCTION_POINTERS;
    }

    /// Overrideable function to provide the list of function pointers for
    /// integrity checks.
    //slither-disable-next-line dead-code
    function integrityFunctionPointers() internal pure virtual returns (bytes memory) {
        return INTEGRITY_FUNCTION_POINTERS;
    }
}
