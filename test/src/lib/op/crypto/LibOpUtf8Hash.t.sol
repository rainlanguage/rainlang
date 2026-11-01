// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";

import {LibOpUtf8Hash} from "../../../../../src/lib/op/crypto/LibOpUtf8Hash.sol";
import {NotAString} from "../../../../../src/error/ErrRainType.sol";
import {LibContext} from "../../../../../src/lib/caller/LibContext.sol";

import {IntOrAString, LibIntOrAString} from "rain-intorastring-0.1.4/src/lib/LibIntOrAString.sol";

import {OperandV2, SourceIndexV2, EvalV4, StackItem} from "../../../../../src/interface/IInterpreterV4.sol";
import {FullyQualifiedNamespace} from "../../../../../src/interface/IInterpreterStoreV3.sol";
import {SignedContextV2} from "../../../../../src/interface/IInterpreterCallerV5.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibDecimalFloat, Float} from "rain-math-float-0.3.11/src/lib/LibDecimalFloat.sol";

/// @title LibOpUtf8HashTest
/// @notice Test the runtime and integrity time logic of LibOpUtf8Hash.
contract LibOpUtf8HashTest is OpTest {
    /// `cast keccak "abcd"`
    bytes32 constant KECCAK_ABCD = 0x48bed44d1bcd124a28c27f343a817e5f5243190d3c52bf347daf876de1dbbf77;
    /// `cast keccak "cdab"`
    bytes32 constant KECCAK_CDAB = 0x732c6a3b69ab23aad6ddb14224c725083a9c2b84ef7277ac48a64f83181687fc;
    /// `cast keccak ""`
    bytes32 constant KECCAK_EMPTY = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
    /// `cast keccak "a"`
    bytes32 constant KECCAK_A = 0x3ac225168df54212a25c1c01fd35bebfea408fdac2e31ddd6f80a4bbf9a5f1cb;
    /// `cast keccak "aaaaaaaaaaaaaaa"`
    bytes32 constant KECCAK_15_A = 0x839e73458ea8f780ea660993ab5754a7211d4d4da14df39f47a70c4b69747d8d;
    /// `cast keccak "0123456789012345678901234567890"`
    bytes32 constant KECCAK_31_CHARS = 0x37580b044dcb770403c020672ee7f35dfc1ca488c71bdd63e186a83ad9422a85;
    /// `cast keccak 0x` followed by 31 `ff` bytes.
    bytes32 constant KECCAK_31_FF = 0xed9376b1543fcc53830b2ebac4ed716319c6ae32bbf19d93881e6985d0b434fa;
    /// `cast keccak "example.org/a/b"`
    bytes32 constant KECCAK_NAME = 0x15706c38735d25a1c78d02e7e621269de0e2face5401d557bbaddc8019458442;
    /// `cast keccak $(cast abi-encode "f(bytes32,bytes32,bytes32)" $(cast keccak "EIP712Domain(string name,string version)") $(cast keccak "example.org/a/b") $(cast keccak "1"))`
    bytes32 constant EIP712_DOMAIN_HASH = 0x4249d5e272b9cb624c80a15ba5467f514777bf9963408b3f4d12157b4e3cfaab;

    /// A string of at most `maxLength` bytes taken from the start of `word`.
    function fuzzString(bytes32 word, uint256 maxLength) internal pure returns (bytes memory) {
        bytes memory s = new bytes((uint256(word) & 0x1f) % (maxLength + 1));
        for (uint256 i = 0; i < s.length; i++) {
            s[i] = word[i];
        }
        return s;
    }

    function fuzzInputs(bytes32[15] memory words, uint8 count)
        internal
        pure
        returns (StackItem[] memory inputs, bytes memory joined)
    {
        inputs = new StackItem[](count);
        for (uint256 i = 0; i < count; i++) {
            bytes memory s = fuzzString(words[i], 31);
            inputs[i] = StackItem.wrap(bytes32(IntOrAString.unwrap(LibIntOrAString.fromStringV3(string(s)))));
            joined = bytes.concat(joined, s);
        }
    }

    function externalRun(OperandV2 operand, StackItem[] memory inputs) external view returns (StackItem[] memory) {
        return opRunOutputs(operand, LibOpUtf8Hash.run, inputs);
    }

    /// Directly test the integrity logic of LibOpUtf8Hash. This tests the happy
    /// path where the operand is valid.
    function testOpUtf8HashIntegrityHappy(
        IntegrityCheckState memory state,
        uint8 inputs,
        uint8 outputs,
        uint16 operandData
    ) external pure {
        inputs = uint8(bound(inputs, 1, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        OperandV2 operand = LibOperand.build(inputs, outputs, operandData);
        (uint256 calcInputs, uint256 calcOutputs) = LibOpUtf8Hash.integrity(state, operand);

        assertEq(inputs, calcInputs);
        assertEq(calcOutputs, 1);
    }

    /// 0 inputs in the operand is calculated as 1 input.
    function testOpUtf8HashIntegrityZeroInputs(IntegrityCheckState memory state, uint8 outputs, uint16 operandData)
        external
        pure
    {
        outputs = uint8(bound(outputs, 0, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpUtf8Hash.integrity(state, LibOperand.build(0, outputs, operandData));

        assertEq(calcInputs, 1);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpUtf8Hash against its reference
    /// implementation.
    function testOpUtf8HashRun(bytes32[15] memory words, uint8 count) external view {
        count = uint8(bound(count, 1, 0x0F));
        (StackItem[] memory inputs,) = fuzzInputs(words, count);
        InterpreterState memory state = opTestDefaultInterpreterState();
        OperandV2 operand = LibOperand.build(count, 1, 0);
        opReferenceCheck(state, operand, LibOpUtf8Hash.referenceFn, LibOpUtf8Hash.integrity, LibOpUtf8Hash.run, inputs);
    }

    /// The runtime output is keccak256 of the input strings concatenated in
    /// input order.
    function testOpUtf8HashRunHashesConcatenatedStrings(bytes32[15] memory words, uint8 count) external view {
        count = uint8(bound(count, 1, 0x0F));
        (StackItem[] memory inputs, bytes memory joined) = fuzzInputs(words, count);
        StackItem[] memory outputs = this.externalRun(LibOperand.build(count, 1, 0), inputs);

        assertEq(outputs.length, 1);
        assertEq(StackItem.unwrap(outputs[0]), keccak256(joined));
    }

    /// Any set bit above a string's bytes reverts with the index and value of
    /// the offending input.
    function testOpUtf8HashRunNotAStringBitsAboveString(
        bytes32[15] memory words,
        uint8 count,
        uint256 index,
        bytes32 badWord,
        uint256 bit
    ) external {
        count = uint8(bound(count, 1, 0x0F));
        index = bound(index, 0, count - 1);
        (StackItem[] memory inputs,) = fuzzInputs(words, count);

        bytes memory s = fuzzString(badWord, 30);
        bit = bound(bit, (s.length + 1) * 8, 255);
        bytes32 bad = bytes32(IntOrAString.unwrap(LibIntOrAString.fromStringV3(string(s))) | (1 << bit));
        inputs[index] = StackItem.wrap(bad);

        vm.expectRevert(abi.encodeWithSelector(NotAString.selector, index, bad));
        this.externalRun(LibOperand.build(count, 1, 0), inputs);
    }

    /// Any of the three truthy bits missing reverts with the index and value of
    /// the offending input.
    function testOpUtf8HashRunNotAStringMissingTruthyBits(
        bytes32[15] memory words,
        uint8 count,
        uint256 index,
        bytes32 badWord,
        uint256 clearBits
    ) external {
        count = uint8(bound(count, 1, 0x0F));
        index = bound(index, 0, count - 1);
        (StackItem[] memory inputs,) = fuzzInputs(words, count);

        clearBits = bound(clearBits, 1, 7) << 5;
        bytes32 bad =
            bytes32(IntOrAString.unwrap(LibIntOrAString.fromStringV3(string(fuzzString(badWord, 31)))) & ~clearBits);
        inputs[index] = StackItem.wrap(bad);

        vm.expectRevert(abi.encodeWithSelector(NotAString.selector, index, bad));
        this.externalRun(LibOperand.build(count, 1, 0), inputs);
    }

    /// Test the eval of a utf8-hash opcode parsed from a string. Tests 1 input.
    function testOpUtf8HashEval1Input() external view {
        checkHappy("_: utf8-hash(\"abcd\");", KECCAK_ABCD, "");
    }

    /// Test the eval of a utf8-hash opcode parsed from a string. Tests 2 inputs
    /// concatenated in source order.
    function testOpUtf8HashEval2Inputs() external view {
        checkHappy("_: utf8-hash(\"ab\" \"cd\");", KECCAK_ABCD, "");
        checkHappy("_: utf8-hash(\"cd\" \"ab\");", KECCAK_CDAB, "");
    }

    /// Test the eval of a utf8-hash opcode parsed from a string. Tests the empty
    /// string.
    function testOpUtf8HashEvalEmptyString() external view {
        checkHappy("_: utf8-hash(\"\");", KECCAK_EMPTY, "");
        checkHappy("_: utf8-hash(\"\" \"\");", KECCAK_EMPTY, "");
        checkHappy("_: utf8-hash(\"\" \"a\" \"\");", KECCAK_A, "");
    }

    /// Test the eval of a utf8-hash opcode parsed from a string. Tests a 31 byte
    /// string, the longest an IntOrAString holds.
    function testOpUtf8HashEval31ByteString() external view {
        checkHappy("_: utf8-hash(\"0123456789012345678901234567890\");", KECCAK_31_CHARS, "");
    }

    /// Test the eval of a utf8-hash opcode parsed from a string. Tests 15 inputs,
    /// the most an operand encodes.
    function testOpUtf8HashEval15Inputs() external view {
        checkHappy(
            "_: utf8-hash(\"a\" \"a\" \"a\" \"a\" \"a\" \"a\" \"a\" \"a\" \"a\" \"a\" \"a\" \"a\" \"a\" \"a\" \"a\");",
            KECCAK_15_A,
            ""
        );
    }

    /// Test the eval of a utf8-hash opcode parsed from a string. Tests a name
    /// assembled from parts.
    function testOpUtf8HashEvalAssembledName() external view {
        checkHappy("_: utf8-hash(\"example.org/\" \"a\" \"/\" \"b\");", KECCAK_NAME, "");
    }

    /// Test the eval of an EIP-712 domain separator over a name and version
    /// hashed by utf8-hash.
    function testOpUtf8HashEvalEIP712Domain() external view {
        checkHappy(
            "_: hash(0xb03948446334eb9b2196d5eb166f69b9d49403eb4a12f36de8d3f9f3cb8e15c3 utf8-hash(\"example.org/\" \"a\" \"/\" \"b\") utf8-hash(\"1\"));",
            EIP712_DOMAIN_HASH,
            ""
        );
    }

    /// Test the eval of a utf8-hash opcode over hex literals that are valid
    /// IntOrAString strings.
    function testOpUtf8HashEvalHexStrings() external view {
        checkHappy("_: utf8-hash(0xe0);", KECCAK_EMPTY, "");
        checkHappy("_: utf8-hash(0x61e1);", KECCAK_A, "");
        checkHappy(
            "_: utf8-hash(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);", KECCAK_31_FF, ""
        );
    }

    /// Test the eval of a utf8-hash opcode parsed from a string. Tests 2 inputs
    /// and other stack items.
    function testOpUtf8HashEval2InputsOtherStack() external view {
        bytes memory bytecode = I_COMPILER.parse2("_ _ _: 5 utf8-hash(\"ab\" \"cd\") 9;");
        (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: FullyQualifiedNamespace.wrap(0),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: LibContext.buildV2(new bytes32[][](0), new SignedContextV2[](0)),
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );
        assertEq(stack.length, 3);
        assertEq(StackItem.unwrap(stack[0]), Float.unwrap(LibDecimalFloat.packLossless(9, 0)));
        assertEq(StackItem.unwrap(stack[1]), KECCAK_ABCD);
        assertEq(StackItem.unwrap(stack[2]), Float.unwrap(LibDecimalFloat.packLossless(5, 0)));
        assertEq(kvs.length, 0);
    }

    /// A number input reverts with NotAString at its input index.
    function testOpUtf8HashEvalNotAStringNumber() external {
        bytes32 one = Float.unwrap(LibDecimalFloat.packLossless(1, 0));
        checkUnhappy("_: utf8-hash(1);", abi.encodeWithSelector(NotAString.selector, 0, one));
        checkUnhappy("_: utf8-hash(\"a\" 1);", abi.encodeWithSelector(NotAString.selector, 1, one));
        checkUnhappy("_: utf8-hash(1 \"a\");", abi.encodeWithSelector(NotAString.selector, 0, one));
    }

    /// A value with a bit set above its string bytes reverts with NotAString at
    /// its input index.
    function testOpUtf8HashEvalNotAStringBitsAboveString() external {
        checkUnhappy("_: utf8-hash(0x01e0);", abi.encodeWithSelector(NotAString.selector, 0, bytes32(uint256(0x01e0))));
        checkUnhappy(
            "_: utf8-hash(\"a\" \"b\" 0x0161e1);",
            abi.encodeWithSelector(NotAString.selector, 2, bytes32(uint256(0x0161e1)))
        );
    }

    /// A value without all three truthy bits reverts with NotAString at its
    /// input index.
    function testOpUtf8HashEvalNotAStringMissingTruthyBits() external {
        checkUnhappy(
            "_: utf8-hash(\"a\" 0x6101);", abi.encodeWithSelector(NotAString.selector, 1, bytes32(uint256(0x6101)))
        );
        checkUnhappy("_: utf8-hash(0x61c1);", abi.encodeWithSelector(NotAString.selector, 0, bytes32(uint256(0x61c1))));
    }

    function testOpUtf8HashZeroInputs() external {
        checkBadInputs("_: utf8-hash();", 0, 1, 0);
    }

    function testOpUtf8HashZeroOutputs() external {
        checkBadOutputs(": utf8-hash(\"a\");", 1, 1, 0);
    }

    function testOpUtf8HashTwoOutputs() external {
        checkBadOutputs("_ _: utf8-hash(\"a\");", 1, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpUtf8HashEvalOperandDisallowed() external {
        checkUnhappyParse("_: utf8-hash<0>(\"a\");", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
