// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {LibIntegrityCheck, IntegrityCheckState} from "../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {LibConvert} from "rain-lib-typecast-0.1.0/src/LibConvert.sol";
import {OperandV2} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterV4.sol";

/// @dev Contract whose integrity function pointers are valid for its own
/// bytecode. Has a single opcode (index 0) that always returns (1, 1).
contract IntegritySingleOp {
    function oneInputOneOutput(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) {
        return (1, 1);
    }

    function buildIntegrityPointers() external pure returns (bytes memory) {
        unchecked {
            function(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256) lengthPointer;
            uint256 length = 1;
            assembly ("memory-safe") {
                lengthPointer := length
            }
            function(IntegrityCheckState memory, OperandV2) internal pure returns (uint256, uint256)[2] memory
                pointersFixed = [lengthPointer, oneInputOneOutput];
            uint256[] memory pointersDynamic;
            assembly ("memory-safe") {
                pointersDynamic := pointersFixed
            }
            return LibConvert.unsafeTo16BitBytes(pointersDynamic);
        }
    }

    function runIntegrityCheck(bytes memory fPointers, bytes memory bytecode, bytes32[] memory constants)
        external
        view
        returns (bytes memory)
    {
        return LibIntegrityCheck.integrityCheck2(fPointers, bytecode, constants);
    }
}
