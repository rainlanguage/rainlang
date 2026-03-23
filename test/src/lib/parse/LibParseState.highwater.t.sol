// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    RainterpreterExpressionDeployerDeploymentTest
} from "test/abstract/RainterpreterExpressionDeployerDeploymentTest.sol";
import {ParseStackOverflow} from "../../../../src/error/ErrParse.sol";

/// @title LibParseStateHighwaterTest
/// @notice Tests for highwater in LibParseState.
contract LibParseStateHighwaterTest is RainterpreterExpressionDeployerDeploymentTest {
    /// 62 or more top-level RHS items overflows the stack RHS offset
    /// (>= 0x3e), triggering ParseStackOverflow. Items are spread across
    /// multiple lines (max 14 per line) to avoid LineRHSItemsOverflow,
    /// and LHS counts match RHS counts to avoid ExcessRHSItems.
    function testParseStackOverflow() external {
        // 5 lines of 13 items each = 65 top-level items > 62 limit.
        // LHS uses _ (discard) repeated to match the 13 RHS items.
        bytes memory line = bytes("_ _ _ _ _ _ _ _ _ _ _ _ _: 1 1 1 1 1 1 1 1 1 1 1 1 1,\n");
        bytes memory lastLine = bytes("_ _: 1 1;");
        bytes memory rainlang = bytes.concat(line, line, line, line, line, lastLine);

        vm.expectRevert(abi.encodeWithSelector(ParseStackOverflow.selector));
        I_PARSER.unsafeParse(rainlang);
    }
}
