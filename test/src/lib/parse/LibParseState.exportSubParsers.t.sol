// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibBytes, Pointer} from "rain.solmem/lib/LibBytes.sol";

/// @title LibParseStateExportSubParsersTest
/// @notice Tests for exporting sub parsers from LibParseState.
contract LibParseStateExportSubParsersTest is Test {
    using LibParseState for ParseState;
    using LibBytes for bytes;

    /// Can round trip any array through the sub parser LL.
    function testExportSubParsers(ParseState memory state, address[] memory values) external pure {
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        state.subParsers = 0;
        for (uint256 i = 0; i < values.length; i++) {
            state.pushSubParser(cursor, bytes32(uint256(uint160(values[i]))));
        }

        address[] memory exported = state.exportSubParsers();
        assertEq(exported.length, values.length);
        for (uint256 i = 0; i < values.length; i++) {
            assertEq(exported[i], values[i]);
        }
    }
}
