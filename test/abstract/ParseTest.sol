// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {LibParse} from "../../src/lib/parse/LibParse.sol";
import {ParseState} from "../../src/lib/parse/LibParseState.sol";

abstract contract ParseTest is Test {
    using LibParse for ParseState;

    /// @notice Parse the given string and return the bytecode and constants.
    /// @param s The string to parse.
    /// @return The parsed bytecode.
    /// @return The parsed constants.
    function parseExternal(string memory s) external view returns (bytes memory, bytes32[] memory) {
        return LibMetaFixture.newState(s).parse();
    }
}
