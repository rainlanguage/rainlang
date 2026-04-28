// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibCamelToKebab} from "./LibCamelToKebab.sol";

contract LibCamelToKebabTest is Test {
    function k(string memory s) internal pure returns (string memory) {
        return LibCamelToKebab.camelToKebab(s);
    }

    function testSimple() external pure {
        assertEq(k("BitwiseAnd"), "bitwise-and");
    }

    function testAcronymBeforeWord() external pure {
        assertEq(k("ERC20Allowance"), "erc20-allowance");
    }

    function testAcronymWithDigitsBeforeWord() external pure {
        assertEq(k("ERC721BalanceOf"), "erc721-balance-of");
    }

    function testLeadingUint() external pure {
        assertEq(k("Uint256ERC20Allowance"), "uint256-erc20-allowance");
    }

    function testSingleChar() external pure {
        assertEq(k("E"), "e");
    }

    function testShortWord() external pure {
        assertEq(k("If"), "if");
    }

    function testMultiWord() external pure {
        assertEq(k("GreaterThanOrEqualTo"), "greater-than-or-equal-to");
    }

    function testTrailingDigit() external pure {
        assertEq(k("Exp2"), "exp2");
    }

    function testAllCaps() external pure {
        assertEq(k("ERC5313Owner"), "erc5313-owner");
    }

    function testCtPop() external pure {
        assertEq(k("CtPop"), "ct-pop");
    }

    function testMaxUint256() external pure {
        assertEq(k("MaxUint256"), "max-uint256");
    }
}
