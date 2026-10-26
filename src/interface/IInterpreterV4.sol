// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {
    FullyQualifiedNamespace,

    // Exported for convenience.
    //forge-lint: disable-next-line(unused-import)
    StateNamespace,
    SourceIndexV2,

    // Exported for convenience.
    //forge-lint: disable-next-line(unused-import)
    DEFAULT_STATE_NAMESPACE,

    // Exported for convenience.
    //forge-lint: disable-next-line(unused-import)
    OPCODE_CONSTANT,

    // Exported for convenience.
    //forge-lint: disable-next-line(unused-import)
    OPCODE_CONTEXT,

    // Exported for convenience.
    //forge-lint: disable-next-line(unused-import)
    OPCODE_EXTERN,

    // Exported for convenience.
    //forge-lint: disable-next-line(unused-import)
    OPCODE_UNKNOWN,

    // Exported for convenience.
    //forge-lint: disable-next-line(unused-import)
    OPCODE_STACK
} from "./deprecated/v2/IInterpreterV3.sol";
import {IInterpreterStoreV3} from "./IInterpreterStoreV3.sol";

/// @dev Operand for an opcode in the interpreter. Encoded as `bytes32` to
/// allow opcode-specific interpretation of the full 32-byte value.
type OperandV2 is bytes32;

/// @dev A single item on the interpreter stack. Encoded as `bytes32` to hold
/// arbitrary 32-byte values, including packed Rain decimal floats.
type StackItem is bytes32;

/// @dev Parameters for a single evaluation of Rainlang bytecode.
/// @param store The store to read/write state from/to.
/// @param namespace The fully qualified namespace for state reads during eval.
/// The interpreter MUST qualify this namespace itself using
/// `LibNamespace.qualifyNamespace` with `msg.sender`. Implementations MUST NOT
/// trust caller-provided values as pre-qualified — the type name is descriptive
/// of the output, not an assertion about the input.
/// @param bytecode The Rainlang bytecode to evaluate.
/// @param sourceIndex The index of the source within the bytecode to evaluate.
/// @param context The context matrix available to the evaluated logic.
/// @param inputs Pre-populated stack items available to the evaluated logic.
/// @param stateOverlay State overrides applied before evaluation for "what if"
/// analysis. Format is implementation-defined (e.g. pairwise key/value).
/// WARNING: Callers that pass a non-empty overlay and then apply the resulting
/// `writes` to the store may produce unexpected state.
struct EvalV4 {
    IInterpreterStoreV3 store;
    FullyQualifiedNamespace namespace;
    bytes bytecode;
    SourceIndexV2 sourceIndex;
    bytes32[][] context;
    StackItem[] inputs;
    bytes32[] stateOverlay;
}

/// @title IInterpreterV4
/// @notice Interface into a standard interpreter that supports:
///
/// - evaluating Rainlang logic provided as rain bytecode in calldata
/// - receiving arbitrary `bytes32[][]` supporting context to be made available
///   to the evaluated logic via. context aware opcodes
/// - receiving arbitrary `bytes32[]` inputs to be made available to the
///   evaluated logic as prepoluated stack items
/// - receiving arbitrary `bytes32[]` stateOverlay to be applied to the
///   state before evaluation to facilitate "what if" analysis
/// - handling subsequent state changes in bulk in response to evaluated logic
/// - namespacing state changes according to the caller's preferences to avoid
///   unwanted key collisions
///
/// The interface is designed to be stable across many versions and
/// implementations of an interpreter, balancing minimalism with features
/// required for a general purpose onchain interpreted compute environment.
///
/// The security model of an interpreter is that it MUST be resilient to
/// malicious expressions even if they dispatch arbitrary internal function
/// pointers during an eval. The interpreter MAY return garbage or exhibit
/// undefined behaviour or error during an eval, _provided that no state changes
/// are persisted_ e.g. in storage, such that only the caller that specifies the
/// malicious expression can be negatively impacted by the result. In turn, the
/// caller must guard itself against arbitrarily corrupt/malicious reverts and
/// return values from any interpreter that it requests an expression from. And
/// so on and so forth up to the externally owned account (EOA) who signs the
/// transaction and agrees to a specific combination of contracts, expressions
/// and interpreters, who can presumably make an informed decision about which
/// to trust.
///
/// The state of an interpreter is expected to be stored in a store that is
/// passed in as a parameter to the eval function. `eval4` will return the
/// writes that are to be applied to the store after the evaluation is complete.
/// The caller is responsible for applying these writes to the store, and is
/// expected to pass them as-is.
interface IInterpreterV4 {
    /// Rainlang magic happens here.
    ///
    /// Pass Rainlang bytecode in calldata, and get back the stack and storage
    /// writes.
    ///
    /// Implementations SHOULD validate bytecode structure (e.g. via
    /// `LibBytecode.checkNoOOBPointers`) before execution.
    ///
    /// Key differences in `eval4`:
    /// - Supports state overlays to facilitate "what if" analysis. Each item
    ///   of state in the overlay will override corresponding gets from the store
    ///   unless/until they are set to something else in the evaluated logic.
    /// - Numbers are treated as packed Rain decimal floats, NOT fixed point
    ///   decimals.
    /// @param eval The eval configuration specifying bytecode, store, namespace,
    /// context, inputs, and state overlay.
    /// @return stack The output stack items from evaluating the specified source.
    /// @return writes Key-value pairs to be applied to the store by the caller.
    function eval4(EvalV4 calldata eval) external view returns (StackItem[] calldata stack, bytes32[] calldata writes);
}
