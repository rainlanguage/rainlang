// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

import {
    IInterpreterStoreV2,
    FullyQualifiedNamespace,

    // Exported for convenience.
    //forge-lint: disable-next-line(unused-import)
    StateNamespace,
    SourceIndexV2,

    // Exported for convenience.
    //forge-lint: disable-next-line(unused-import)
    DEFAULT_STATE_NAMESPACE,

    // Exported for convenience.
    //forge-lint: disable-next-line(unused-import)
    Operand,

    // Exported for convenience.
    //forge-lint: disable-next-line(unused-import)
    OPCODE_CONSTANT,

    // Exported for convenience.
    //forge-lint: disable-next-line(unused-import)
    OPCODE_CONTEXT,

    // Exported for convenience.
    //forge-lint: disable-next-line(unused-import)
    OPCODE_EXTERN,

    // Exported for convenience.
    //forge-lint: disable-next-line(unused-import)
    OPCODE_UNKNOWN,

    // Exported for convenience.
    //forge-lint: disable-next-line(unused-import)
    OPCODE_STACK
} from "../v1/IInterpreterV2.sol";

interface IInterpreterV3 {
    function functionPointers() external view returns (bytes calldata);

    function eval3(
        IInterpreterStoreV2 store,
        FullyQualifiedNamespace namespace,
        bytes calldata bytecode,
        SourceIndexV2 sourceIndex,
        uint256[][] calldata context,
        uint256[] calldata inputs
    ) external view returns (uint256[] calldata stack, uint256[] calldata writes);
}
