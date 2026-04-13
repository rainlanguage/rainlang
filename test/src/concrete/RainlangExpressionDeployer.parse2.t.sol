// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {MissingFinalSemi} from "../../../src/error/ErrParse.sol";
import {BadOpInputsLength} from "rain.interpreter.interface/error/ErrIntegrity.sol";
import {LibParseError} from "../../../src/lib/parse/LibParseError.sol";

contract RainlangExpressionDeployerParse2Test is OpTest {
    /// parse2 with empty input must return valid serialized bytecode
    /// with zero sources.
    function testParse2EmptyInput() external view {
        bytes memory result = I_DEPLOYER.parse2("");
        assertTrue(result.length > 0);
    }

    /// parse2 with malformed Rainlang must propagate the parse error.
    function testParse2MissingFinalSemi() external {
        vm.expectRevert(abi.encodeWithSelector(MissingFinalSemi.selector, LibParseError.tagErrorOffset(4)));
        I_DEPLOYER.parse2("_: 1");
    }

    /// parse2 with input that parses but fails integrity must propagate
    /// the integrity error.
    function testParse2IntegrityFailure() external {
        // add is opIndex 1, needs 2 inputs, bytecode says 1.
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 1, 2, 1));
        I_DEPLOYER.parse2("_: add(1);");
    }
}
