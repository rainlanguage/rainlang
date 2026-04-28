// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {PragmaV1} from "rain.interpreter.interface/interface/IParserPragmaV1.sol";
import {NoWhitespaceAfterUsingWordsFrom} from "../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../src/lib/parse/LibParseError.sol";

contract RainlangExpressionDeployerParsePragma1Test is OpTest {
    /// No pragma keyword yields empty usingWordsFrom.
    function testParsePragma1NoPragma() external view {
        PragmaV1 memory pragma_ = I_DEPLOYER.parsePragma1(bytes("_: 1;"));
        assertEq(pragma_.usingWordsFrom.length, 0);
    }

    /// Single address pragma.
    function testParsePragma1SingleAddress() external view {
        PragmaV1 memory pragma_ =
            I_DEPLOYER.parsePragma1(bytes("using-words-from 0x4050b49bA93f5774f66f54F06a6042552d76308A _: 1;"));
        assertEq(pragma_.usingWordsFrom.length, 1);
        assertEq(pragma_.usingWordsFrom[0], 0x4050b49bA93f5774f66f54F06a6042552d76308A);
    }

    /// Two address pragma.
    function testParsePragma1TwoAddresses() external view {
        PragmaV1 memory pragma_ = I_DEPLOYER.parsePragma1(
            bytes(
                "using-words-from 0x4050b49bA93f5774f66f54F06a6042552d76308A 0xfa56232Df6ABea43Dda27C197DFECe8383CF1368 _: 1;"
            )
        );
        assertEq(pragma_.usingWordsFrom.length, 2);
        assertEq(pragma_.usingWordsFrom[0], 0x4050b49bA93f5774f66f54F06a6042552d76308A);
        assertEq(pragma_.usingWordsFrom[1], 0xfa56232Df6ABea43Dda27C197DFECe8383CF1368);
    }

    /// Error must propagate through the deployer proxy.
    function testParsePragma1ErrorPropagation() external {
        vm.expectRevert(
            abi.encodeWithSelector(NoWhitespaceAfterUsingWordsFrom.selector, LibParseError.tagErrorOffset(16))
        );
        I_DEPLOYER.parsePragma1(bytes("using-words-from"));
    }
}
