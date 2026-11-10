// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainlangCompilerDeploymentTest} from "test/abstract/RainlangCompilerDeploymentTest.sol";
import {DotrainComposeCasesTest} from "test/abstract/DotrainComposeCasesTest.sol";
import {LibDotrainCompose} from "../../../src/lib/dotrain/LibDotrainCompose.sol";
import {IParserDotrainV1, DotrainBinding} from "../../../src/interface/IParserDotrainV1.sol";
import {MissingFinalSemi} from "../../../src/error/ErrParse.sol";
import {BadOpInputsLength} from "../../../src/error/ErrIntegrity.sol";
import {LibParseError} from "../../../src/lib/parse/LibParseError.sol";
import {
    DotrainMissingFrontMatter,
    DotrainEntrypointNotFound,
    DotrainEntrypointNotExpression,
    DotrainElidedBinding,
    DotrainNotALiteralBinding,
    DotrainAliasShadowsBinding,
    DotrainUnsupported,
    DotrainInvalidBindingName,
    DotrainDuplicateBinding,
    DotrainBindingNotFound,
    DotrainBindingNotRebindable
} from "../../../src/error/ErrDotrain.sol";

contract BaseRainlangCompilerParseDotrain2IsParse2OfComposeTest is
    RainlangCompilerDeploymentTest,
    DotrainComposeCasesTest
{
    function composeThenParse2(string memory dotrain, string memory entrypoint, DotrainBinding[] memory bound)
        external
        view
        returns (bytes memory)
    {
        return I_COMPILER.parse2(bytes(LibDotrainCompose.compose(dotrain, entrypoint, bound)));
    }

    function checkMatchesParse2(string memory dotrain, string memory entrypoint, DotrainBinding[] memory bound)
        internal
        view
        returns (bool)
    {
        (bool expectedSuccess, bytes memory expected) =
            address(this).staticcall(abi.encodeCall(this.composeThenParse2, (dotrain, entrypoint, bound)));
        (bool success, bytes memory actual) =
            address(I_COMPILER).staticcall(abi.encodeCall(IParserDotrainV1.parseDotrain2, (dotrain, entrypoint, bound)));
        assertEq(success, expectedSuccess, dotrain);
        assertEq(actual, expected, dotrain);
        return success;
    }

    function checkCase(string memory dotrain, string memory entrypoint, DotrainBinding[] memory bound)
        internal
        view
        override
    {
        checkMatchesParse2(dotrain, entrypoint, bound);
    }

    function testStandardOpsDotrainCompiles(bytes32 a, bytes32 b, bool bindB) external view {
        DotrainBinding[] memory bound = new DotrainBinding[](bindB ? 2 : 1);
        bound[0] = DotrainBinding("a", a);
        if (bindB) bound[1] = DotrainBinding("b", b);
        assertTrue(checkMatchesParse2("---\n#a !A.\n#b 5\n#c \"s\"\n#e\n_: add(a b),\n_ _: c a;", "e", bound));
    }

    function checkRefusal(
        bytes memory err,
        string memory dotrain,
        string memory entrypoint,
        DotrainBinding[] memory bound
    ) internal {
        vm.expectRevert(err);
        I_COMPILER.parseDotrain2(dotrain, entrypoint, bound);
    }

    function testComposeRefusalsRevertFromParseDotrain2() external {
        DotrainBinding[] memory none = new DotrainBinding[](0);
        DotrainBinding[] memory unknown = new DotrainBinding[](1);
        unknown[0] = DotrainBinding("nope", bytes32(0));
        DotrainBinding[] memory expression = new DotrainBinding[](1);
        expression[0] = DotrainBinding("e", bytes32(0));

        checkRefusal(abi.encodeWithSelector(DotrainMissingFrontMatter.selector), "#e _: 1;", "e", none);
        checkRefusal(abi.encodeWithSelector(DotrainEntrypointNotFound.selector, "f"), "---\n#e _: 1;", "f", none);
        checkRefusal(
            abi.encodeWithSelector(DotrainEntrypointNotExpression.selector, "x"), "---\n#x 1\n#e _: 1;", "x", none
        );
        checkRefusal(abi.encodeWithSelector(DotrainElidedBinding.selector, "x"), "---\n#x !need\n#e _: x;", "e", none);
        checkRefusal(
            abi.encodeWithSelector(DotrainNotALiteralBinding.selector, "y"), "---\n#y _: 1;\n#e _: y;", "e", none
        );
        checkRefusal(abi.encodeWithSelector(DotrainAliasShadowsBinding.selector, "x"), "---\n#x 1\n#e x: 2;", "e", none);
        checkRefusal(abi.encodeWithSelector(DotrainUnsupported.selector, 13), "---\n#e _: 1;\n@0x01 x", "e", none);
        checkRefusal(abi.encodeWithSelector(DotrainInvalidBindingName.selector, 5), "---\n#X 1\n#e _: 1;", "e", none);
        checkRefusal(
            abi.encodeWithSelector(DotrainDuplicateBinding.selector, "x"), "---\n#x 1\n#x 2\n#e _: 1;", "e", none
        );
        checkRefusal(
            abi.encodeWithSelector(DotrainBindingNotFound.selector, "nope"), "---\n#x 1\n#e _: x;", "e", unknown
        );
        checkRefusal(
            abi.encodeWithSelector(DotrainBindingNotRebindable.selector, "e"), "---\n#x 1\n#e _: x;", "e", expression
        );
    }

    function testParseErrorsRevertFromParseDotrain2() external {
        DotrainBinding[] memory none = new DotrainBinding[](0);
        checkRefusal(
            abi.encodeWithSelector(MissingFinalSemi.selector, LibParseError.tagErrorOffset(4)),
            "---\n#e _: 1",
            "e",
            none
        );
        checkRefusal(abi.encodeWithSelector(BadOpInputsLength.selector, 1, 2, 1), "---\n#e _: add(1);", "e", none);
    }
}
