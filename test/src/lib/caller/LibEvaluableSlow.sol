// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {EvaluableV2} from "../../../../src/interface/deprecated/v1/IInterpreterCallerV2.sol";
import {EvaluableV4} from "../../../../src/interface/IInterpreterCallerV5.sol";

library LibEvaluableSlow {
    function hashSlow(EvaluableV2 memory evaluable) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                uint256(uint160(address(evaluable.interpreter))),
                uint256(uint160(address(evaluable.store))),
                uint256(uint160(evaluable.expression))
            )
        );
    }

    function hashSlow(EvaluableV4 memory evaluable) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                keccak256(
                    abi.encodePacked(
                        uint256(uint160(address(evaluable.interpreter))), uint256(uint160(address(evaluable.store)))
                    )
                ),
                keccak256(evaluable.bytecode)
            )
        );
    }
}
