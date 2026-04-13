// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainlangExpressionDeployerDeploymentTest} from "test/abstract/RainlangExpressionDeployerDeploymentTest.sol";
import {NotAcceptingInputs} from "../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";

/// @title LibParseStateEndLineTest
/// @notice Tests for endLine in LibParseState.
contract LibParseStateEndLineTest is RainlangExpressionDeployerDeploymentTest {
    /// A second input-only line (no RHS) after the first line has RHS items
    /// must revert with NotAcceptingInputs. The FSM stops accepting inputs
    /// after the first RHS opcode.
    function testNotAcceptingInputs() external {
        // Line 1: "_: 1" has an RHS opcode, so FSM stops accepting inputs.
        // Line 2: "a:" has only LHS with no RHS — triggers NotAcceptingInputs.
        vm.expectRevert(abi.encodeWithSelector(NotAcceptingInputs.selector, LibParseError.tagErrorOffset(8)));
        I_PARSER.unsafeParse(bytes("_: 1,\na:;"));
    }
}
