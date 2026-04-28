// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {InterpreterState} from "../../../src/lib/state/LibInterpreterState.sol";

/// @title LibInterpreterStateFingerprint
/// @notice Test-only library for computing a keccak256 fingerprint of interpreter
/// state. Used to detect state mutations between evaluation calls.
library LibInterpreterStateFingerprint {
    function fingerprint(InterpreterState memory state) internal pure returns (bytes32) {
        return keccak256(abi.encode(state));
    }
}
