// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

import {FullyQualifiedNamespace} from "./IInterpreterStoreV1.sol";
// Exported for convenience.
//forge-lint: disable-next-line(unused-import)
import {IInterpreterV1, SourceIndex} from "./IInterpreterV1.sol";

interface IDebugExpressionDeployerV1 {
    function offchainDebugEval(
        bytes[] memory sources,
        uint256[] memory constants,
        FullyQualifiedNamespace namespace,
        uint256[][] memory context,
        SourceIndex sourceIndex,
        uint256[] memory initialStack,
        uint8 minOutputs
    ) external view returns (uint256[] memory finalStack, uint256[] memory kvs);
}
