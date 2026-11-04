// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";

import {EIP712} from "@openzeppelin-contracts-5.7.0/utils/cryptography/EIP712.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.7.0/utils/cryptography/MessageHashUtils.sol";

import {LibOpEIP712DomainSeparator} from "../../../../../src/lib/op/crypto/LibOpEIP712DomainSeparator.sol";
import {EIP712DomainFieldsInvalid} from "../../../../../src/error/ErrIntegrity.sol";
import {ExpectedOperand} from "../../../../../src/error/ErrParse.sol";
import {OperandV2, StackItem} from "../../../../../src/interface/IInterpreterV4.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibDecimalFloat, Float} from "rain-math-float-0.3.11/src/lib/LibDecimalFloat.sol";
import {Pointer} from "rain-solmem-0.1.28/src/lib/LibPointer.sol";

/// @title EIP712DomainSeparatorSource
/// @notice An OpenZeppelin `EIP712` contract exposing its domain separator.
contract EIP712DomainSeparatorSource is EIP712 {
    constructor(string memory name, string memory version) EIP712(name, version) {}

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
}

/// @title LibOpEIP712DomainSeparatorTest
/// @notice Test the runtime and integrity time logic of
/// LibOpEIP712DomainSeparator.
contract LibOpEIP712DomainSeparatorTest is OpTest {
    function fieldCount(uint256 fields) internal pure returns (uint8) {
        uint8 count = 0;
        for (uint256 bit = 0; bit < 5; bit++) {
            if ((fields >> bit) & 1 == 1) {
                count++;
            }
        }
        return count;
    }

    /// The selected fields in canonical order, each as its `abi.encode` word.
    function domainInputs(
        uint256 fields,
        bytes32 nameHash,
        bytes32 versionHash,
        uint256 chainId,
        address verifyingContract,
        bytes32 salt
    ) internal pure returns (StackItem[] memory) {
        bytes32[5] memory all = [
            nameHash, versionHash, bytes32(chainId), bytes32(uint256(uint160(verifyingContract))), salt
        ];
        StackItem[] memory inputs = new StackItem[](fieldCount(fields));
        uint256 cursor = 0;
        for (uint256 bit = 0; bit < 5; bit++) {
            if ((fields >> bit) & 1 == 1) {
                inputs[cursor] = StackItem.wrap(all[bit]);
                cursor++;
            }
        }
        return inputs;
    }

    function wordsInputs(uint256 fields, bytes32[5] memory words) internal pure returns (StackItem[] memory) {
        StackItem[] memory inputs = new StackItem[](fieldCount(fields));
        for (uint256 i = 0; i < inputs.length; i++) {
            inputs[i] = StackItem.wrap(words[i]);
        }
        return inputs;
    }

    function externalIntegrity(OperandV2 operand) external pure returns (uint256, uint256) {
        return LibOpEIP712DomainSeparator.integrity(opTestDefaultIngegrityCheckState(), operand);
    }

    /// Integrity takes one input per selected field and gives one output,
    /// whatever the operand's input and output bits say.
    function testOpEIP712DomainSeparatorIntegrityHappy(
        IntegrityCheckState memory state,
        uint8 inputs,
        uint8 outputs,
        uint16 fields
    ) external pure {
        inputs = uint8(bound(inputs, 0, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        fields = uint16(bound(fields, 1, 0x1F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpEIP712DomainSeparator.integrity(state, LibOperand.build(inputs, outputs, fields));

        assertEq(calcInputs, fieldCount(fields));
        assertEq(calcOutputs, 1);
    }

    /// A mask selecting no field reverts at integrity.
    function testOpEIP712DomainSeparatorIntegrityZeroFields(uint8 inputs, uint8 outputs) external {
        inputs = uint8(bound(inputs, 0, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        vm.expectRevert(abi.encodeWithSelector(EIP712DomainFieldsInvalid.selector, 0));
        this.externalIntegrity(LibOperand.build(inputs, outputs, 0));
    }

    /// A mask with any bit above `salt` reverts at integrity.
    function testOpEIP712DomainSeparatorIntegrityFieldsAboveSalt(uint8 inputs, uint8 outputs, uint16 fields) external {
        inputs = uint8(bound(inputs, 0, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        fields = uint16(bound(fields, 0x20, type(uint16).max));
        vm.expectRevert(abi.encodeWithSelector(EIP712DomainFieldsInvalid.selector, fields));
        this.externalIntegrity(LibOperand.build(inputs, outputs, fields));
    }

    /// Run matches the reference implementation for every mask over arbitrary
    /// words.
    function testOpEIP712DomainSeparatorRunReference(uint16 fields, bytes32[5] memory words) external view {
        fields = uint16(bound(fields, 1, 0x1F));
        StackItem[] memory inputs = wordsInputs(fields, words);
        opReferenceCheck(
            opTestDefaultInterpreterState(),
            LibOperand.build(fieldCount(fields), 1, fields),
            LibOpEIP712DomainSeparator.referenceFn,
            LibOpEIP712DomainSeparator.integrity,
            LibOpEIP712DomainSeparator.run,
            inputs
        );
    }

    /// For each of the 31 field subsets, run gives OpenZeppelin's ERC-5267
    /// domain separator over the same fields.
    function testOpEIP712DomainSeparatorRunMatchesOpenZeppelin(
        string memory name,
        string memory version,
        uint256 chainId,
        address verifyingContract,
        bytes32 salt
    ) external view {
        bytes32 nameHash = keccak256(bytes(name));
        bytes32 versionHash = keccak256(bytes(version));
        for (uint8 fields = 1; fields <= 0x1F; fields++) {
            StackItem[] memory outputs = opRunOutputs(
                LibOperand.build(fieldCount(fields), 1, fields),
                LibOpEIP712DomainSeparator.run,
                domainInputs(fields, nameHash, versionHash, chainId, verifyingContract, salt)
            );
            assertEq(outputs.length, 1);
            assertEq(
                StackItem.unwrap(outputs[0]),
                MessageHashUtils.toDomainSeparator(bytes1(fields), name, version, chainId, verifyingContract, salt)
            );
        }
    }

    /// An OpenZeppelin `EIP712` contract's ERC-5267 domain, fed through run,
    /// gives that contract's own domain separator.
    function testOpEIP712DomainSeparatorRunMatchesEIP712Contract(
        string memory name,
        string memory version,
        uint64 chainId
    ) external {
        vm.chainId(chainId);
        EIP712DomainSeparatorSource source = new EIP712DomainSeparatorSource(name, version);
        (
            bytes1 fields,
            string memory domainName,
            string memory domainVersion,
            uint256 domainChainId,
            address verifyingContract,
            bytes32 salt,
        ) = source.eip712Domain();
        StackItem[] memory outputs = opRunOutputs(
            LibOperand.build(fieldCount(uint8(fields)), 1, uint8(fields)),
            LibOpEIP712DomainSeparator.run,
            domainInputs(
                uint8(fields),
                keccak256(bytes(domainName)),
                keccak256(bytes(domainVersion)),
                domainChainId,
                verifyingContract,
                salt
            )
        );
        assertEq(StackItem.unwrap(outputs[0]), source.domainSeparator());
    }

    /// Run's scratch writes leave memory below the free memory pointer intact.
    function testOpEIP712DomainSeparatorRunPreservesAllocatedMemory(uint16 fields, bytes32[5] memory words)
        external
        view
    {
        fields = uint16(bound(fields, 1, 0x1F));
        StackItem[] memory inputs = wordsInputs(fields, words);
        InterpreterState memory state = opTestDefaultInterpreterState();
        OperandV2 operand = LibOperand.build(fieldCount(fields), 1, fields);
        Pointer stackTop = opReferenceCheckPointers(inputs, 1).stackTop;
        bytes32[] memory allocated = new bytes32[](6);
        for (uint256 i = 0; i < allocated.length; i++) {
            allocated[i] = bytes32(type(uint256).max);
        }
        LibOpEIP712DomainSeparator.run(state, operand, stackTop);
        for (uint256 i = 0; i < allocated.length; i++) {
            assertEq(allocated[i], bytes32(type(uint256).max));
        }
    }

    /// For each of the 31 field subsets, the parsed word evals to
    /// OpenZeppelin's ERC-5267 domain separator over the same fields.
    function testOpEIP712DomainSeparatorEvalMatchesOpenZeppelin(
        bytes32 nameHash,
        bytes32 versionHash,
        uint256 chainId,
        address verifyingContract,
        bytes32 salt
    ) external view {
        for (uint8 fields = 1; fields <= 0x1F; fields++) {
            StackItem[] memory inputs = domainInputs(fields, nameHash, versionHash, chainId, verifyingContract, salt);
            bytes memory args = "";
            for (uint256 i = 0; i < inputs.length; i++) {
                args = bytes.concat(args, " ", bytes(vm.toString(StackItem.unwrap(inputs[i]))));
            }
            checkHappy(
                bytes.concat("_: eip712-domain-separator<", bytes(vm.toString(fields)), ">(", args, ");"),
                MessageHashUtils.toDomainSeparator(
                    bytes1(fields), nameHash, versionHash, chainId, verifyingContract, salt
                ),
                ""
            );
        }
    }

    /// Name and version hashed by utf8-hash give the same separator as the
    /// hand-built typehash and `hash` form.
    function testOpEIP712DomainSeparatorEvalUtf8HashNameVersion() external view {
        (StackItem[] memory word,) =
            parseAndEval("_: eip712-domain-separator<3>(utf8-hash(\"example.org/a/b\") utf8-hash(\"1\"));");
        (StackItem[] memory handBuilt,) = parseAndEval(
            "_: hash(0xb03948446334eb9b2196d5eb166f69b9d49403eb4a12f36de8d3f9f3cb8e15c3 utf8-hash(\"example.org/a/b\") utf8-hash(\"1\"));"
        );
        assertEq(
            StackItem.unwrap(word[0]),
            MessageHashUtils.toDomainSeparator(
                bytes1(0x03), string("example.org/a/b"), string("1"), 0, address(0), bytes32(0)
            )
        );
        assertEq(StackItem.unwrap(word[0]), StackItem.unwrap(handBuilt[0]));
    }

    /// The word leaves the stack items around it intact.
    function testOpEIP712DomainSeparatorEvalOtherStack() external view {
        (StackItem[] memory stack, bytes32[] memory kvs) =
            parseAndEval("_ _ _: 5 eip712-domain-separator<1>(utf8-hash(\"a\")) 9;");
        assertEq(stack.length, 3);
        assertEq(StackItem.unwrap(stack[0]), Float.unwrap(LibDecimalFloat.packLossless(9, 0)));
        assertEq(
            StackItem.unwrap(stack[1]),
            MessageHashUtils.toDomainSeparator(bytes1(0x01), string("a"), string(""), 0, address(0), bytes32(0))
        );
        assertEq(StackItem.unwrap(stack[2]), Float.unwrap(LibDecimalFloat.packLossless(5, 0)));
        assertEq(kvs.length, 0);
    }

    /// A zero mask reverts at parse.
    function testOpEIP712DomainSeparatorEvalZeroFields() external {
        checkUnhappyParse2(
            "_: eip712-domain-separator<0>();", abi.encodeWithSelector(EIP712DomainFieldsInvalid.selector, 0)
        );
    }

    /// A mask with any bit above `salt` reverts at parse.
    function testOpEIP712DomainSeparatorEvalFieldsAboveSalt() external {
        checkUnhappyParse2(
            "_: eip712-domain-separator<32>();", abi.encodeWithSelector(EIP712DomainFieldsInvalid.selector, 32)
        );
        checkUnhappyParse2(
            "_: eip712-domain-separator<33>(0x01);", abi.encodeWithSelector(EIP712DomainFieldsInvalid.selector, 33)
        );
        checkUnhappyParse2(
            "_: eip712-domain-separator<65535>();", abi.encodeWithSelector(EIP712DomainFieldsInvalid.selector, 65535)
        );
    }

    /// The operand is required.
    function testOpEIP712DomainSeparatorEvalOperandOmitted() external {
        checkUnhappyParse("_: eip712-domain-separator(0x01);", abi.encodeWithSelector(ExpectedOperand.selector));
        checkUnhappyParse("_: eip712-domain-separator<>(0x01);", abi.encodeWithSelector(ExpectedOperand.selector));
    }

    /// The input count must match the number of selected fields.
    function testOpEIP712DomainSeparatorEvalBadInputs() external {
        checkBadInputs("_: eip712-domain-separator<3>(0x01);", 1, 2, 1);
        checkBadInputs("_: eip712-domain-separator<1>(0x01 0x02);", 2, 1, 2);
    }

    function testOpEIP712DomainSeparatorZeroOutputs() external {
        checkBadOutputs(": eip712-domain-separator<1>(0x01);", 1, 1, 0);
    }

    function testOpEIP712DomainSeparatorTwoOutputs() external {
        checkBadOutputs("_ _: eip712-domain-separator<1>(0x01);", 1, 1, 2);
    }
}
