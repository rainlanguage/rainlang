// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {
    LibDotrainCompose,
    DotrainBinding,
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
} from "./LibDotrainCompose.sol";

contract LibDotrainComposeRefusalsTest is Test {
    function externalCompose(string memory dotrain, string memory entrypoint, DotrainBinding[] memory bound)
        external
        pure
        returns (string memory)
    {
        return LibDotrainCompose.compose(dotrain, entrypoint, bound);
    }

    function noBindings() internal pure returns (DotrainBinding[] memory) {
        return new DotrainBinding[](0);
    }

    function checkUnsupported(string memory prefix, string memory rest, uint256 offsetInRest) internal {
        vm.expectRevert(abi.encodeWithSelector(DotrainUnsupported.selector, bytes(prefix).length + offsetInRest));
        this.externalCompose(string.concat(prefix, rest), "e", noBindings());
    }

    function checkInvalidBindingName(string memory prefix, string memory rest, uint256 offsetInRest) internal {
        vm.expectRevert(abi.encodeWithSelector(DotrainInvalidBindingName.selector, bytes(prefix).length + offsetInRest));
        this.externalCompose(string.concat(prefix, rest), "e", noBindings());
    }

    function testNoFrontMatterDelimiterReverts() external {
        vm.expectRevert(abi.encodeWithSelector(DotrainMissingFrontMatter.selector));
        this.externalCompose("#e _: 1;", "e", noBindings());
        vm.expectRevert(abi.encodeWithSelector(DotrainMissingFrontMatter.selector));
        this.externalCompose("--\n#e _: 1;", "e", noBindings());
    }

    function testMissingEntrypointReverts() external {
        vm.expectRevert(abi.encodeWithSelector(DotrainEntrypointNotFound.selector, "f"));
        this.externalCompose("---\n#e _: 1;", "f", noBindings());
        vm.expectRevert(abi.encodeWithSelector(DotrainEntrypointNotFound.selector, "e"));
        this.externalCompose("#e _: 1;\n---", "e", noBindings());
    }

    function testLiteralEntrypointReverts() external {
        vm.expectRevert(abi.encodeWithSelector(DotrainEntrypointNotExpression.selector, "x"));
        this.externalCompose("---\n#x 1\n#e _: 1;", "x", noBindings());
    }

    function testElidedEntrypointReverts() external {
        vm.expectRevert(abi.encodeWithSelector(DotrainEntrypointNotExpression.selector, "x"));
        this.externalCompose("---\n#x !need\n#e _: 1;", "x", noBindings());
    }

    function testUnboundElidedReferenceReverts() external {
        vm.expectRevert(abi.encodeWithSelector(DotrainElidedBinding.selector, "x"));
        this.externalCompose("---\n#x !need\n#e _: x;", "e", noBindings());
    }

    function testUnboundElidedPragmaReverts() external {
        vm.expectRevert(abi.encodeWithSelector(DotrainElidedBinding.selector, "x"));
        this.externalCompose("---\n#x !need\n#e using-words-from x\n_: 1;", "e", noBindings());
    }

    function testExpressionReferenceReverts() external {
        vm.expectRevert(abi.encodeWithSelector(DotrainNotALiteralBinding.selector, "y"));
        this.externalCompose("---\n#y _: 1;\n#e _: y;", "e", noBindings());
        vm.expectRevert(abi.encodeWithSelector(DotrainNotALiteralBinding.selector, "y"));
        this.externalCompose("---\n#y 1 2\n#e _: y;", "e", noBindings());
    }

    function testExpressionPragmaReverts() external {
        vm.expectRevert(abi.encodeWithSelector(DotrainNotALiteralBinding.selector, "y"));
        this.externalCompose("---\n#y _: 1;\n#e using-words-from y\n_: 1;", "e", noBindings());
    }

    function testLhsNamedAsBindingReverts() external {
        vm.expectRevert(abi.encodeWithSelector(DotrainAliasShadowsBinding.selector, "x"));
        this.externalCompose("---\n#x 1\n#e x: 2;", "e", noBindings());
        vm.expectRevert(abi.encodeWithSelector(DotrainAliasShadowsBinding.selector, "x"));
        this.externalCompose("---\n#x 1\n#e _: 1, _ x: 2 3;", "e", noBindings());
        vm.expectRevert(abi.encodeWithSelector(DotrainAliasShadowsBinding.selector, "x"));
        this.externalCompose("---\n#x 1\n#e _: 1; x: 2;", "e", noBindings());
    }

    function testImportReverts() external {
        checkUnsupported("---\n#e _: 1;\n", "@0x01 x", 0);
    }

    function testQuoteBindingReverts() external {
        checkUnsupported("---\n#q ", "'e\n#e _: 1;", 0);
    }

    function testQuoteInEntrypointReverts() external {
        checkUnsupported("---\n#x 1\n#e _: ", "'x;", 0);
    }

    function testNamespacePathReverts() external {
        checkUnsupported("---\n#e _: ", "a.b;", 1);
    }

    function testIdentifierInOperandReverts() external {
        checkUnsupported("---\n#x 1\n#e _: foo<", "0 x>();", 2);
    }

    function testEmptyBindingBodyReverts() external {
        checkUnsupported("---\n#x", "\n#e _: 1;", 0);
        checkUnsupported("---\n#e _: 1;\n#x", "", 0);
        checkUnsupported("---\n#x", " /* c */ \n#e _: 1;", 0);
    }

    function testUnclosedCommentReverts() external {
        checkUnsupported("---\n#e _: 1; ", "/* never closed", 0);
    }

    function testUnclosedStringReverts() external {
        checkUnsupported("---\n#e _: ", "\"abc", 4);
    }

    function testUnclosedSubParserReverts() external {
        checkUnsupported("---\n#e _: ", "[abc", 4);
    }

    function testUnclosedOperandReverts() external {
        checkUnsupported("---\n#e _: ", "foo<1 2", 7);
    }

    function testTextBeforeFirstBindingReverts() external {
        checkUnsupported("---\n", "stray\n#e _: 1;", 0);
    }

    function testInvalidBindingNameReverts() external {
        checkInvalidBindingName("---\n#", "X 1\n#e _: 1;", 0);
        checkInvalidBindingName("---\n#", "1x 1\n#e _: 1;", 0);
        checkInvalidBindingName("---\n#", "-x 1\n#e _: 1;", 0);
        checkInvalidBindingName("---\n#", "x_y 1\n#e _: 1;", 1);
        checkInvalidBindingName("---\n#", "xY 1\n#e _: 1;", 1);
        checkInvalidBindingName("---\n#", " 1\n#e _: 1;", 0);
        checkInvalidBindingName("---\n#e _: 1;\n#", "", 0);
    }

    function testDuplicateBindingReverts() external {
        vm.expectRevert(abi.encodeWithSelector(DotrainDuplicateBinding.selector, "x"));
        this.externalCompose("---\n#x 1\n#e _: 1;\n#x 2", "e", noBindings());
        vm.expectRevert(abi.encodeWithSelector(DotrainDuplicateBinding.selector, "x"));
        this.externalCompose("---\n#x 1\n#x 2\n#e _: 1;", "e", noBindings());
    }

    function testUnknownBoundNameReverts() external {
        DotrainBinding[] memory bound = new DotrainBinding[](1);
        bound[0] = DotrainBinding("nope", bytes32(0));
        vm.expectRevert(abi.encodeWithSelector(DotrainBindingNotFound.selector, "nope"));
        this.externalCompose("---\n#x 1\n#e _: x;", "e", bound);
    }

    function testBoundExpressionReverts() external {
        DotrainBinding[] memory bound = new DotrainBinding[](1);
        bound[0] = DotrainBinding("e", bytes32(0));
        vm.expectRevert(abi.encodeWithSelector(DotrainBindingNotRebindable.selector, "e"));
        this.externalCompose("---\n#x 1\n#e _: x;", "e", bound);
    }
}
