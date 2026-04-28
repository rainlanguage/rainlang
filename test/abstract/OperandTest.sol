// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParse} from "../../src/lib/parse/LibParse.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {ParseState} from "../../src/lib/parse/LibParseState.sol";

abstract contract OperandTest is Test {
    using LibParse for ParseState;

    // External version of parse for testing. Expect revert only works properly
    // when called externally.
    function parse(bytes memory rainString) external view returns (bytes memory bytecode, bytes32[] memory constants) {
        return LibMetaFixture.newState(string(rainString)).parse();
    }

    function checkParseError(bytes memory rainString, bytes memory err) internal {
        bytes memory bytecode;
        bytes32[] memory constants;
        vm.expectRevert(err);
        (bytecode, constants) = this.parse(rainString);
        (bytecode);
        (constants);
    }

    function checkOperandParse(bytes memory rainString, bytes memory operand) internal view {
        (bytes memory bytecode, bytes32[] memory constants) = this.parse(rainString);
        assertEq(
            bytecode,
            bytes.concat(
                // 1 source
                hex"01"
                // 0 offset
                hex"0000"
                // 1 op
                hex"01"
                // 1 stack allocation
                hex"01"
                // 0 inputs
                hex"00"
                // 1 output
                hex"01",
                operand
            )
        );
        assertEq(constants.length, 0);
    }
}
