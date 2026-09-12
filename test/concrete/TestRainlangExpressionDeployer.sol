// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {BaseRainlangExpressionDeployer} from "../../src/abstract/BaseRainlangExpressionDeployer.sol";
import {BaseRainlangParser} from "../../src/abstract/BaseRainlangParser.sol";
import {LibAllStandardOps} from "../../src/lib/op/LibAllStandardOps.sol";
import {TEST_PARSER_ADDRESS} from "../lib/deploy/LibTestInterpreterDeploy.sol";
// Referenced by NatSpec only.
//forge-lint: disable-next-line(unused-import)
import {IDescribedByMetaV1} from "rain-metadata-0.1.7/src/interface/IDescribedByMetaV1.sol";

/// @dev Stands in for the meta hash a deployed expression deployer describes
/// itself by; the test concrete has no meta.
bytes32 constant TEST_DESCRIBED_BY_META_HASH = keccak256("TestRainlangExpressionDeployer");

/// @title TestRainlangExpressionDeployer
/// @notice `BaseRainlangExpressionDeployer` over the current source: the
/// integrity function pointers are read from `LibAllStandardOps` at runtime
/// and the parser is the one `LibTestInterpreterDeploy` places at
/// `TEST_PARSER_ADDRESS`.
contract TestRainlangExpressionDeployer is BaseRainlangExpressionDeployer {
    /// @inheritdoc BaseRainlangExpressionDeployer
    function parser() internal pure virtual override returns (BaseRainlangParser) {
        return BaseRainlangParser(TEST_PARSER_ADDRESS);
    }

    /// @inheritdoc BaseRainlangExpressionDeployer
    function integrityFunctionPointers() internal pure virtual override returns (bytes memory) {
        return LibAllStandardOps.integrityFunctionPointers();
    }

    /// @inheritdoc IDescribedByMetaV1
    function describedByMetaV1() external pure virtual override returns (bytes32) {
        return TEST_DESCRIBED_BY_META_HASH;
    }
}
