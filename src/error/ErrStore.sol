// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @dev Workaround for https://github.com/foundry-rs/foundry/issues/6572
contract ErrStore {}

/// @notice Thrown when a `set` call is made with an odd number of arguments.
/// @param length The length of the key/value array.
error OddSetLength(uint256 length);
