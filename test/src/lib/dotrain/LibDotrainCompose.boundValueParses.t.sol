// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ParseTest} from "test/abstract/ParseTest.sol";
import {LibDotrainCompose} from "../../../../src/lib/dotrain/LibDotrainCompose.sol";
import {DotrainBinding} from "../../../../src/interface/IParserDotrainV1.sol";

contract LibDotrainComposeBoundValueParsesTest is ParseTest {
    function testHexLiteralIsLowercaseHex(bytes32 value) external pure {
        assertEq(LibDotrainCompose.hexLiteral(value), vm.toString(value));
    }

    function testBoundValueParsesToItsConstant(bytes32 value, bool elided) external view {
        DotrainBinding[] memory bound = new DotrainBinding[](1);
        bound[0] = DotrainBinding("x", value);
        string memory composed =
            LibDotrainCompose.compose(elided ? "---\n#x !value\n#e _: x;" : "---\n#x 5\n#e _: x;", "e", bound);
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal(composed);
        (bytes memory expectedBytecode,) = this.parseExternal(string.concat("_: ", vm.toString(value), ";"));
        assertEq(constants.length, 1);
        assertEq(constants[0], value);
        assertEq(bytecode, expectedBytecode);
    }
}
