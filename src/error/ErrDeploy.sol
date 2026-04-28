// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @dev Workaround for https://github.com/foundry-rs/foundry/issues/6572
contract ErrDeploy {}

/// @notice Thrown when the `DEPLOYMENT_SUITE` env var does not match any known suite
/// selector.
/// @param suite The unrecognised suite selector hash.
error UnknownDeploymentSuite(bytes32 suite);
