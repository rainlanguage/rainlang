// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {RainlangParser} from "../../../src/concrete/RainlangParser.sol";
import {PragmaV1} from "rain.interpreter.interface/interface/IParserPragmaV1.sol";
import {NoWhitespaceAfterUsingWordsFrom} from "../../../src/error/ErrParse.sol";

contract RainlangParserParserPragma is Test {
    function checkPragma(bytes memory source, address[] memory expectedAddresses) internal {
        RainlangParser parser = new RainlangParser();
        PragmaV1 memory pragmaV2 = parser.parsePragma1(source);
        assert(pragmaV2.usingWordsFrom.length == expectedAddresses.length);
        for (uint256 i = 0; i < expectedAddresses.length; i++) {
            assert(pragmaV2.usingWordsFrom[i] == expectedAddresses[i]);
        }
    }

    function testParsePragmaNoPragma() external {
        checkPragma(":;", new address[](0));
        checkPragma("using-words-from :;", new address[](0));
        checkPragma("using-words-from foo:;", new address[](0));
        checkPragma("using-words-from foo:1;", new address[](0));
        checkPragma("using-words-from _:1;", new address[](0));
    }

    function testParsePragmaSinglePragma() external {
        address[] memory addresses = new address[](1);
        addresses[0] = address(0);
        checkPragma("using-words-from 0x0000000000000000000000000000000000000000 foo:1;", addresses);
        addresses[0] = address(0x4050b49bA93f5774f66f54F06a6042552d76308A);
        checkPragma("using-words-from 0x4050b49bA93f5774f66f54F06a6042552d76308A foo:1;", addresses);
        addresses = new address[](2);
        addresses[0] = address(0x4050b49bA93f5774f66f54F06a6042552d76308A);
        addresses[1] = address(0xfa56232Df6ABea43Dda27C197DFECe8383CF1368);
        checkPragma(
            "using-words-from 0x4050b49bA93f5774f66f54F06a6042552d76308A 0xfa56232Df6ABea43Dda27C197DFECe8383CF1368 foo:1;",
            addresses
        );
    }

    /// Input ending exactly at the pragma keyword with no trailing whitespace
    /// must revert.
    function testParsePragmaNoWhitespaceAfterKeyword() external {
        RainlangParser parser = new RainlangParser();
        vm.expectRevert(abi.encodeWithSelector(NoWhitespaceAfterUsingWordsFrom.selector, 16));
        parser.parsePragma1("using-words-from");
    }

    function testParsePragmaWithInterstitial() external {
        address[] memory addresses = new address[](1);

        addresses[0] = address(0);
        checkPragma("   using-words-from 0x0000000000000000000000000000000000000000 foo:1;", addresses);

        addresses[0] = address(0x4050b49bA93f5774f66f54F06a6042552d76308A);
        checkPragma("/*   foo    */ \n using-words-from 0x4050b49bA93f5774f66f54F06a6042552d76308A foo:1;", addresses);

        addresses = new address[](2);
        addresses[0] = address(0x4050b49bA93f5774f66f54F06a6042552d76308A);
        addresses[1] = address(0xfa56232Df6ABea43Dda27C197DFECe8383CF1368);
        checkPragma(
            "/* */ using-words-from 0x4050b49bA93f5774f66f54F06a6042552d76308A 0xfa56232Df6ABea43Dda27C197DFECe8383CF1368 foo:1;",
            addresses
        );
    }
}
