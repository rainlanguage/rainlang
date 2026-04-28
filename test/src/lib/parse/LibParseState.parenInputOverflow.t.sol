// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {OperandV2} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {ParenInputOverflow} from "../../../../src/error/ErrParse.sol";

contract LibParseStateParenInputOverflowTest is Test {
    using LibParseState for ParseState;

    /// External wrapper so expectRevert works.
    function externalPushOpWithMaxParenCounter() external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");
        // Set the paren input counter at level 0 to 0xFF so the next
        // pushOpToSource triggers ParenInputOverflow.
        // parenTracker0 layout: byte 0 = nesting offset (0),
        // byte 1 = input counter for level 0.
        // Setting byte 1 to 0xFF.
        state.parenTracker0 = uint256(0xFF) << 240;
        state.pushOpToSource(0, OperandV2.wrap(bytes32(0)));
    }

    /// Pushing an op when the paren input counter is at 0xFF must revert
    /// with ParenInputOverflow.
    function testParenInputOverflow() external {
        vm.expectRevert(abi.encodeWithSelector(ParenInputOverflow.selector));
        this.externalPushOpWithMaxParenCounter();
    }
}
