// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    RainlangExpressionDeployerDeploymentTest
} from "test/abstract/RainlangExpressionDeployerDeploymentTest.sol";

/// @title LibIntegrityCheckHighwaterTest
/// @notice Tests that readHighwater advances after a multi-output opcode.
contract LibIntegrityCheckHighwaterTest is RainlangExpressionDeployerDeploymentTest {
    /// A multi-output call (2 outputs) must pass the integrity check.
    /// The call opcode returns (sourceInputs, outputs) where outputs > 1,
    /// which triggers readHighwater advancement in the multi-output
    /// branch of LibIntegrityCheck. If highwater did not advance correctly,
    /// parse2 would revert during its internal integrity check.
    function testHighwaterAdvancesAfterMultiOutputCall() external view {
        I_DEPLOYER.parse2(bytes("a b: call<1>(10); ten:,a b:ten 11;"));
    }
}
