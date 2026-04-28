// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @dev Workaround for https://github.com/foundry-rs/foundry/issues/6572
contract ErrRainType {}

/// @notice Thrown when a value expected to be an address has non-zero upper 96
/// bits. This indicates the value is not a valid address and was likely produced
/// by a non-address operation (e.g. a hash, a float, or arithmetic).
/// @param value The invalid value that is not a valid address.
error NotAnAddress(uint256 value);
