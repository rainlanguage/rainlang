// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @dev Workaround for https://github.com/foundry-rs/foundry/issues/6572
contract ErrEval {}

/// @notice Thrown when the inputs length does not match the expected inputs length.
/// @param expected The expected number of inputs.
/// @param actual The actual number of inputs.
error InputsLengthMismatch(uint256 expected, uint256 actual);

/// @notice Thrown when the function pointer table is empty, which would cause
/// mod-by-zero in the eval loop opcode dispatch.
error ZeroFunctionPointers();

/// @notice Thrown when `agree` is given a negative tolerance. A spread is a
/// distance and so never negative, which makes a negative tolerance
/// meaningless rather than merely strict. It is representable only because
/// floats are signed, and it reaches the word as a typo or a miscomputed
/// constant. Reverting fails closed, where accepting it would let the other
/// tolerance silently carry the check.
error AgreeToleranceNegative();

/// @notice Thrown when neither of `agree`'s tolerances is positive. At least
/// one has to be, or there is no tolerance at all and the word is an exact
/// equality check — which is `equal-to`'s job, so it means the wrong word was
/// written rather than that a tolerance of nothing was wanted. Either
/// tolerance ALONE may be zero; that is how an expression asks for only the
/// other one.
error AgreeNoPositiveTolerance();
