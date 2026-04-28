// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {OperandV2} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {DanglingSource} from "../../../../src/error/ErrParse.sol";

contract LibParseStateDanglingSourceTest is Test {
    using LibParseState for ParseState;

    /// External wrapper so expectRevert works.
    function externalBuildBytecodeWithDanglingSource() external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");
        // Push an op without ending the source, leaving activeSource != EMPTY_ACTIVE_SOURCE.
        state.pushOpToSource(0, OperandV2.wrap(bytes32(0)));
        state.buildBytecode();
    }

    /// Calling buildBytecode with an active (non-ended) source must revert
    /// with DanglingSource.
    function testDanglingSource() external {
        vm.expectRevert(abi.encodeWithSelector(DanglingSource.selector));
        this.externalBuildBytecodeWithDanglingSource();
    }
}
