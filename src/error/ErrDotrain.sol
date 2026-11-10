// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @dev Workaround for https://github.com/foundry-rs/foundry/issues/6572
contract ErrDotrain {}

/// The dotrain has no `---` front matter delimiter.
error DotrainMissingFrontMatter();

/// The requested entrypoint is not a binding in the dotrain.
/// @param name The entrypoint name.
error DotrainEntrypointNotFound(string name);

/// The requested entrypoint is not an expression binding.
/// @param name The entrypoint name.
error DotrainEntrypointNotExpression(string name);

/// The entrypoint references an elided binding that was not given a value.
/// @param name The binding name.
error DotrainElidedBinding(string name);

/// The entrypoint references a binding that is not a literal.
/// @param name The binding name.
error DotrainNotALiteralBinding(string name);

/// An LHS name in the entrypoint shadows a binding name.
/// @param name The binding name.
error DotrainAliasShadowsBinding(string name);

/// Input outside the supported dotrain subset (imports, quotes, namespace
/// paths, identifiers inside operands).
/// @param offset Byte offset into the dotrain source.
error DotrainUnsupported(uint256 offset);

/// A binding name does not match `^[a-z][0-9a-z-]*$`.
/// @param offset Byte offset into the dotrain source.
error DotrainInvalidBindingName(uint256 offset);

/// Two bindings in the dotrain share a name.
/// @param name The binding name.
error DotrainDuplicateBinding(string name);

/// A `-b` binding names no binding in the dotrain.
/// @param name The binding name.
error DotrainBindingNotFound(string name);

/// A `-b` binding names an expression binding.
/// @param name The binding name.
error DotrainBindingNotRebindable(string name);
