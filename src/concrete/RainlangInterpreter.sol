// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {LibMemoryKV, MemoryKVKey, MemoryKVVal} from "rain.lib.memkv/lib/LibMemoryKV.sol";

import {LibEval} from "../lib/eval/LibEval.sol";
import {LibInterpreterStateDataContract} from "../lib/state/LibInterpreterStateDataContract.sol";
import {InterpreterState} from "../lib/state/LibInterpreterState.sol";
import {LibAllStandardOps} from "../lib/op/LibAllStandardOps.sol";
import {
    IInterpreterV4,
    SourceIndexV2,
    EvalV4,
    StackItem
} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {

    // Exported for convenience.
    //forge-lint: disable-next-line(unused-import)
    BYTECODE_HASH as INTERPRETER_BYTECODE_HASH,
    OPCODE_FUNCTION_POINTERS
} from "../generated/RainlangInterpreter.pointers.sol";
import {IOpcodeToolingV1} from "rain.sol.codegen/interface/IOpcodeToolingV1.sol";
import {OddSetLength} from "../error/ErrStore.sol";
import {ZeroFunctionPointers} from "../error/ErrEval.sol";

/// @title RainlangInterpreter
/// @notice Implementation of a Rainlang interpreter that is compatible with
/// native onchain Rainlang parsing.
contract RainlangInterpreter is IInterpreterV4, IOpcodeToolingV1, ERC165 {
    using LibEval for InterpreterState;
    using LibInterpreterStateDataContract for bytes;

    /// Guards against deployment with an empty opcode function pointer table,
    /// which would make every eval call revert.
    constructor() {
        if (opcodeFunctionPointers().length == 0) revert ZeroFunctionPointers();
    }

    /// @notice Returns the packed 2-byte function pointer table used by the
    /// eval loop to dispatch each opcode. Virtual so subclasses can override
    /// the table. Overrides MUST return the same non-empty value at construction
    /// time and at runtime. Returning empty bytes at runtime would cause
    /// division-by-zero in the eval loop's modulo-based dispatch, leading to
    /// reads from arbitrary memory interpreted as function pointers.
    /// @return The opcode function pointers for the interpreter.
    function opcodeFunctionPointers() internal view virtual returns (bytes memory) {
        return OPCODE_FUNCTION_POINTERS;
    }

    /// @inheritdoc IInterpreterV4
    function eval4(EvalV4 calldata eval) external view virtual override returns (StackItem[] memory, bytes32[] memory) {
        InterpreterState memory state = eval.bytecode
            .unsafeDeserialize(
                SourceIndexV2.unwrap(eval.sourceIndex),
                eval.namespace,
                eval.store,
                eval.context,
                opcodeFunctionPointers()
            );
        if (eval.stateOverlay.length % 2 != 0) {
            revert OddSetLength(eval.stateOverlay.length);
        }
        for (uint256 i = 0; i < eval.stateOverlay.length; i += 2) {
            state.stateKV = LibMemoryKV.set(
                state.stateKV, MemoryKVKey.wrap(eval.stateOverlay[i]), MemoryKVVal.wrap(eval.stateOverlay[i + 1])
            );
        }
        // We use the return by returning it. Slither false positive.
        //slither-disable-next-line unused-return
        return state.eval4(eval.inputs, type(uint256).max);
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IInterpreterV4).interfaceId || interfaceId == type(IOpcodeToolingV1).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IOpcodeToolingV1
    function buildOpcodeFunctionPointers() public view virtual override returns (bytes memory) {
        return LibAllStandardOps.opcodeFunctionPointers();
    }
}
