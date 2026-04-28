// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {IntegrityCheckState, BadOpInputsLength} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {LibOpERC721OwnerOf} from "../../../../../src/lib/op/erc721/LibOpERC721OwnerOf.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {
    FullyQualifiedNamespace,
    SourceIndexV2,
    OperandV2,
    EvalV4,
    StackItem
} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibContext} from "rain.interpreter.interface/lib/caller/LibContext.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV4.sol";
import {UnexpectedOperand} from "../../../../../src/error/ErrParse.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";

import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {NotAnAddress} from "../../../../../src/error/ErrRainType.sol";
import {LibTestCast} from "test/lib/typecast/LibTestCast.sol";
import {LibBytes32Array} from "rain.solmem/lib/LibBytes32Array.sol";

/// @title LibOpERC721OwnerOfTest
/// @notice Test the opcode for getting the owner of an erc721 token.
contract LibOpERC721OwnerOfTest is OpTest {
    using LibTestCast for StackItem[];
    using LibBytes32Array for bytes32[];

    function testOpERC721OwnerOfIntegrity(IntegrityCheckState memory state, uint8 inputs) external pure {
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpERC721OwnerOf.integrity(state, OperandV2.wrap(bytes32(uint256(inputs) << 0x10)));

        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    function testOpERC721OwnerOfRun(address token, bytes32 tokenId, address owner, uint16 operandData) external {
        assumeEtchable(token);
        vm.etch(token, hex"fe");
        vm.mockCall(token, abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId), abi.encode(owner));
        // called once for reference, once for run
        vm.expectCall(token, abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId), 2);

        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(token))));
        inputs[1] = StackItem.wrap(tokenId);
        OperandV2 operand = LibOperand.build(2, 1, operandData);

        opReferenceCheck(
            opTestDefaultInterpreterState(),
            operand,
            LibOpERC721OwnerOf.referenceFn,
            LibOpERC721OwnerOf.integrity,
            LibOpERC721OwnerOf.run,
            inputs
        );
    }

    function testOpERC721OwnerOfEvalHappy(address token, uint256 tokenId, address owner) public {
        bytes memory bytecode = I_DEPLOYER.parse2(
            bytes(
                string.concat(
                    "_: erc721-owner-of(", Strings.toHexString(token), " ", Strings.toHexString(tokenId), ");"
                )
            )
        );

        assumeEtchable(token);
        vm.etch(token, hex"fe");
        vm.mockCall(token, abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId), abi.encode(owner));
        vm.expectCall(token, abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId), 1);

        (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: FullyQualifiedNamespace.wrap(0),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: LibContext.build(new bytes32[][](0), new SignedContextV1[](0)),
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );
        assertEq(stack.length, 1);
        assertEq(StackItem.unwrap(stack[0]), bytes32(uint256(uint160(owner))));
        assertEq(kvs.length, 0);
    }

    /// Test that owner of without inputs fails integrity check.
    function testOpERC721OwnerOfEvalFail0() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 0, 2, 0));
        bytes memory bytecode = I_DEPLOYER.parse2("_: erc721-owner-of();");
        (bytecode);
    }

    /// Test that owner of with one input fails integrity check.
    function testOpERC721OwnerOfEvalFail1() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 1, 2, 1));
        bytes memory bytecode = I_DEPLOYER.parse2("_: erc721-owner-of(0x00);");
        (bytecode);
    }

    /// Test that owner of with too many inputs fails integrity check.
    function testOpERC721OwnerOfEvalFail3() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 3, 2, 3));
        bytes memory bytecode = I_DEPLOYER.parse2("_: erc721-owner-of(0x00 0x01 0x02);");
        (bytecode);
    }

    /// Test that operand fails integrity check.
    function testOpERC721OwnerOfEvalFailOperand() public {
        vm.expectRevert(abi.encodeWithSelector(UnexpectedOperand.selector));
        (bytes memory bytecode, bytes32[] memory constants) = I_PARSER.unsafeParse("_: erc721-owner-of<0>(0x00 0x01);");
        (bytecode, constants);
    }

    /// Test that non-address token input reverts.
    function testOpERC721OwnerOfNotAnAddressToken(uint256 token) external {
        // Casting to `uint160` is intentional to detect non-address values.
        //forge-lint: disable-next-line(unsafe-typecast)
        vm.assume(token != uint256(uint160(token)));
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(token));
        inputs[1] = StackItem.wrap(bytes32(uint256(1)));
        OperandV2 operand = LibOperand.build(2, 1, 0);
        vm.expectRevert(abi.encodeWithSelector(NotAnAddress.selector, token));
        this.externalRun(operand, inputs);
    }

    function externalRun(OperandV2 operand, StackItem[] memory inputs) external view {
        LibOpERC721OwnerOf.run(opTestDefaultInterpreterState(), operand, inputs.asBytes32Array().dataPointer());
    }

    function testOpERC721OwnerOfEvalZeroInputs() external {
        checkBadInputs("_: erc721-owner-of();", 0, 2, 0);
    }

    function testOpERC721OwnerOfEvalOneInput() external {
        checkBadInputs("_: erc721-owner-of(0x00);", 1, 2, 1);
    }

    function testOpERC721OwnerOfEvalThreeInputs() external {
        checkBadInputs("_: erc721-owner-of(0x00 0x01 0x02);", 3, 2, 3);
    }

    function testOpERC721OwnerOfEvalZeroOutputs() external {
        checkBadOutputs(": erc721-owner-of(0x00 0x01);", 2, 1, 0);
    }

    function testOpERC721OwnerOfTwoOutputs() external {
        checkBadOutputs("_ _: erc721-owner-of(0x00 0x01);", 2, 1, 2);
    }
}
