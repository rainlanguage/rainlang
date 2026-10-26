// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

// Exported for convenience.
//forge-lint: disable-next-line(unused-import)
import {IParserV2} from "../../IParserV2.sol";
import {IInterpreterStoreV3} from "../../IInterpreterStoreV3.sol";
import {IInterpreterV4} from "../../IInterpreterV4.sol";
import {

    // Exported for convenience.
    //forge-lint: disable-start(unused-import)
    SignedContextV1,
    SIGNED_CONTEXT_SIGNER_OFFSET,
    SIGNED_CONTEXT_CONTEXT_OFFSET,
    SIGNED_CONTEXT_SIGNATURE_OFFSET
} from "../v2/IInterpreterCallerV3.sol";

//forge-lint: disable-end

/// @param interpreter Will evaluate the expression. Callers MUST NOT use an
/// `EvaluableV4` with a zero or untrusted interpreter address.
/// @param store Will store state changes due to evaluation of the expression.
/// MAY be `address(0)` only if the expression never writes state.
/// @param bytecode Will be evaluated by the interpreter.
struct EvaluableV4 {
    IInterpreterV4 interpreter;
    IInterpreterStoreV3 store;
    bytes bytecode;
}

/// @title IInterpreterCallerV4
/// @notice A contract that calls an `IInterpreterV4` via. `eval4`. There are
/// near zero requirements on a caller other than:
///
/// - Provide the context, which can be built in a standard way by `LibContext`
/// - Handle the stack array returned from `eval4`
/// - OPTIONALLY emit the `Context` event
/// - OPTIONALLY set state on the associated `IInterpreterStoreV3`.
interface IInterpreterCallerV4 {
    /// Calling contracts SHOULD emit `Context` before calling `eval4` if they
    /// are able. Notably `eval4` MAY be called within a static call which means
    /// that events cannot be emitted, in which case this does not apply. It MAY
    /// NOT be useful to emit this multiple times for several eval calls if they
    /// all share a common context, in which case a single emit is sufficient.
    /// @param sender `msg.sender` building the context.
    /// @param context The context that was built.
    event ContextV2(address sender, bytes32[][] context);
}
