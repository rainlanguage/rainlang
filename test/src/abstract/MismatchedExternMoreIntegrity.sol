// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {TestableExtern} from "./TestableExtern.sol";

/// @dev Extern with 1 opcode pointer but 2 integrity pointers.
contract MismatchedExternMoreIntegrity is TestableExtern {
    function opcodeFunctionPointers() internal pure override returns (bytes memory) {
        return hex"0001";
    }

    function integrityFunctionPointers() internal pure override returns (bytes memory) {
        return hex"00010002";
    }
}
