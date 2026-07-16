// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {TestableExtern} from "./TestableExtern.sol";

/// @dev Extern with 2 opcode pointers but 1 integrity pointer.
contract MismatchedExternMoreOpcodes is TestableExtern {
    function opcodeFunctionPointers() internal pure override returns (bytes memory) {
        return hex"00010002";
    }

    function integrityFunctionPointers() internal pure override returns (bytes memory) {
        return hex"0001";
    }
}
