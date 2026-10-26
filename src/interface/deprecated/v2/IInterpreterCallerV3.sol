// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

// Exported for convenience.
//forge-lint: disable-next-line(unused-import)
import {IParserV2} from "../../IParserV2.sol";
import {IInterpreterStoreV2} from "./IInterpreterStoreV2.sol";
import {IInterpreterV3} from "./IInterpreterV3.sol";
import {

    // Exported for convenience.
    //forge-lint: disable-start(unused-import)
    SignedContextV1,
    SIGNED_CONTEXT_SIGNER_OFFSET,
    SIGNED_CONTEXT_CONTEXT_OFFSET,
    SIGNED_CONTEXT_SIGNATURE_OFFSET
} from "../v1/IInterpreterCallerV2.sol";

//forge-lint: disable-end

/// Struct over the return of `IParserV2.parse2` which MAY be more convenient to
/// work with than raw addresses.
/// @param interpreter Will evaluate the expression.
/// @param store Will store state changes due to evaluation of the expression.
/// @param expression Will be evaluated by the interpreter.
struct EvaluableV3 {
    IInterpreterV3 interpreter;
    IInterpreterStoreV2 store;
    bytes bytecode;
}

/// @title IInterpreterCallerV3
/// @notice A contract that calls an `IInterpreterV3` via. `eval3`. There are
/// near zero requirements on a caller other than:
///
/// - Provide the context, which can be built in a standard way by `LibContext`
/// - Handle the stack array returned from `eval3`
/// - OPTIONALLY emit the `Context` event
/// - OPTIONALLY set state on the `IInterpreterStoreV2` returned from `eval3`.
interface IInterpreterCallerV3 {
    /// Calling contracts SHOULD emit `Context` before calling `eval3` if they
    /// are able. Notably `eval3` MAY be called within a static call which means
    /// that events cannot be emitted, in which case this does not apply. It MAY
    /// NOT be useful to emit this multiple times for several eval calls if they
    /// all share a common context, in which case a single emit is sufficient.
    /// @param sender `msg.sender` building the context.
    /// @param context The context that was built.
    event Context(address sender, uint256[][] context);
}
