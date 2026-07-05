// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {TestableExtern} from "./TestableExtern.sol";

/// @dev Extern with empty opcode and integrity pointers.
contract EmptyPointersExtern is TestableExtern {
    function opcodeFunctionPointers() internal pure override returns (bytes memory) {
        return hex"";
    }

    function integrityFunctionPointers() internal pure override returns (bytes memory) {
        return hex"";
    }
}
