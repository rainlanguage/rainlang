// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {RainlangParser} from "../../../src/concrete/RainlangParser.sol";
import {PragmaV1} from "rain.interpreter.interface/interface/IParserPragmaV1.sol";

/// @title RainlangParserParsePragmaEmptyInputTest
/// @notice Test that `parsePragma1` handles empty input correctly.
contract RainlangParserParsePragmaEmptyInputTest is Test {
    /// @notice parsePragma1 with empty bytes should return a PragmaV1 with an
    /// empty usingWordsFrom array.
    function testParsePragma1EmptyInput() external {
        RainlangParser parser = new RainlangParser();
        PragmaV1 memory pragma_ = parser.parsePragma1(bytes(""));
        assertEq(pragma_.usingWordsFrom.length, 0, "empty input should produce zero sub-parsers");
    }

    /// @notice parsePragma1 with a single null byte should also not revert and
    /// should produce zero sub-parsers.
    function testParsePragma1SingleNullByte() external {
        RainlangParser parser = new RainlangParser();
        PragmaV1 memory pragma_ = parser.parsePragma1(bytes(hex"00"));
        assertEq(pragma_.usingWordsFrom.length, 0, "null byte should produce zero sub-parsers");
    }
}
