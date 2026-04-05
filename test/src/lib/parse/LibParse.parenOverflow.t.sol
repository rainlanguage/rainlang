// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    RainlangExpressionDeployerDeploymentTest
} from "test/abstract/RainlangExpressionDeployerDeploymentTest.sol";
import {ParenOverflow} from "../../../../src/error/ErrParse.sol";

/// @title LibParseParenOverflowTest
/// @notice Tests for paren overflow in LibParse.
contract LibParseParenOverflowTest is RainlangExpressionDeployerDeploymentTest {
    /// Exactly 19 levels of paren nesting must succeed.
    /// 62 bytes of group data at 3 bytes each fits 20 by size, but
    /// pushOpToSource zeroes a phantom counter one slot ahead, so the
    /// effective max is 19 (parenOffset 57, phantom write at byte 61).
    function testParenMaxNesting() external view {
        bytes memory inner = bytes("1 2");
        for (uint256 i = 0; i < 19; i++) {
            inner = bytes.concat(bytes("add("), inner, bytes(" 1)"));
        }
        bytes memory rainlang = bytes.concat(bytes("_: "), inner, bytes(";"));
        I_PARSER.unsafeParse(rainlang);
    }

    /// 20 levels overflows (parenOffset 60 > 59).
    function testParenOverflow() external {
        bytes memory inner = bytes("1 2");
        for (uint256 i = 0; i < 20; i++) {
            inner = bytes.concat(bytes("add("), inner, bytes(" 1)"));
        }
        bytes memory rainlang = bytes.concat(bytes("_: "), inner, bytes(";"));

        vm.expectRevert(abi.encodeWithSelector(ParenOverflow.selector));
        I_PARSER.unsafeParse(rainlang);
    }
}
