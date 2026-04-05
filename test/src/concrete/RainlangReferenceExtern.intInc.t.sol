// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {
    RainlangReferenceExtern,
    OP_INDEX_INCREMENT,
    LibExternOpIntInc
} from "../../../src/concrete/extern/RainlangReferenceExtern.sol";
import {
    ExternDispatchV2,
    EncodedExternDispatchV2,
    IInterpreterExternV4,
    StackItem
} from "rain.interpreter.interface/interface/IInterpreterExternV4.sol";
import {OperandV2, OPCODE_EXTERN} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibExtern} from "../../../src/lib/extern/LibExtern.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";

contract RainlangReferenceExternIntIncTest is OpTest {
    using Strings for address;
    using LibDecimalFloat for Float;

    function testRainlangReferenceExternIntIncHappyUnsugared() external {
        RainlangReferenceExtern extern = new RainlangReferenceExtern();

        uint256 intIncOpcode = 0;

        ExternDispatchV2 externDispatch = LibExtern.encodeExternDispatch(intIncOpcode, OperandV2.wrap(0));
        EncodedExternDispatchV2 encodedExternDispatch = LibExtern.encodeExternCall(extern, externDispatch);

        assertEq(
            EncodedExternDispatchV2.unwrap(encodedExternDispatch),
            0x0000000000000000000000005615deb798bb3e4dfa0139dfa1b3d433cc23b72f
        );

        StackItem[] memory expectedStack = new StackItem[](3);
        expectedStack[0] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(4e66, -66)));
        expectedStack[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(3e66, -66)));
        expectedStack[2] = StackItem.wrap(EncodedExternDispatchV2.unwrap(encodedExternDispatch));

        checkHappy(
            // Need the constant in the constant array to be indexable in the operand.
            "_: 0x0000000000000000000000005615deb798bb3e4dfa0139dfa1b3d433cc23b72f,"
            // Operand is the constant index of the dispatch.
            "three four: extern<0>(2 3);",
            expectedStack,
            "inc 2 3 = 3 4"
        );
    }

    function testRainlangReferenceExternIntIncHappySugared() external {
        RainlangReferenceExtern extern = new RainlangReferenceExtern();

        StackItem[] memory expectedStack = new StackItem[](2);
        expectedStack[0] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(4e66, -66)));
        expectedStack[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(3e66, -66)));

        checkHappy(
            bytes(
                string.concat("using-words-from ", address(extern).toHexString(), " three four: ref-extern-inc(2 3);")
            ),
            expectedStack,
            "sugared inc 2 3 = 3 4"
        );
    }

    /// Directly test the subparsing of the reference extern opcode.
    /// forge-config: default.fuzz.runs = 100
    function testRainlangReferenceExternIntIncSubParseKnownWord(uint16 constantsHeight, bytes1 ioByte) external {
        // Extern "only" supports up to constant height of 0xFF.
        constantsHeight = uint16(bound(constantsHeight, 0, 0xFF));
        RainlangReferenceExtern subParser = new RainlangReferenceExtern();

        bytes memory wordToParse = bytes("ref-extern-inc");
        (bool success, bytes memory bytecode, bytes32[] memory constants) = subParser.subParseWord2(
            bytes.concat(bytes2(constantsHeight), ioByte, bytes2(uint16(wordToParse.length)), wordToParse, bytes32(0))
        );
        assertTrue(success);

        assertEq(bytecode.length, 4);
        assertEq(uint256(uint8(bytecode[0])), OPCODE_EXTERN);
        assertEq(bytecode[1], ioByte);
        // Low bytes for the extern opcode is the constants index of the extern
        // dispatch.
        assertEq((uint16(uint8(bytecode[2])) << 8) | uint16(uint8(bytecode[3])), constantsHeight);

        assertEq(constants.length, 1);
        (IInterpreterExternV4 decodedExtern, ExternDispatchV2 decodedExternDispatch) =
            LibExtern.decodeExternCall(EncodedExternDispatchV2.wrap(constants[0]));

        // The sub parser is also the extern contract because the reference
        // implementation includes both.
        assertEq(address(decodedExtern), address(subParser));

        (uint256 opcode, OperandV2 operand) = LibExtern.decodeExternDispatch(decodedExternDispatch);
        assertEq(opcode, OP_INDEX_INCREMENT);
        assertEq(OperandV2.unwrap(operand), 0);
    }

    /// Directly test the subparsing of the reference extern opcode. Check that
    /// we get a false for success if the subparser doesn't recognize the word
    /// but the data is otherwise valid.
    /// forge-config: default.fuzz.runs = 100
    function testRainlangReferenceExternIntIncSubParseUnknownWord(
        uint16 constantsHeight,
        bytes1 ioByte,
        bytes memory unknownWord
    ) external {
        vm.assume(keccak256(unknownWord) != keccak256("ref-extern-inc"));
        vm.assume(keccak256(unknownWord) != keccak256("ref-extern-stack-operand"));
        vm.assume(keccak256(unknownWord) != keccak256("ref-extern-context-sender"));
        vm.assume(keccak256(unknownWord) != keccak256("ref-extern-context-contract"));
        vm.assume(keccak256(unknownWord) != keccak256("ref-extern-context-rainlen"));
        vm.assume(unknownWord.length < 32);
        // Extern "only" supports up to constant height of 0xFF.
        constantsHeight = uint16(bound(constantsHeight, 0, 0xFF));
        RainlangReferenceExtern subParser = new RainlangReferenceExtern();

        (bool success, bytes memory bytecode, bytes32[] memory constants) = subParser.subParseWord2(
            bytes.concat(bytes2(constantsHeight), ioByte, bytes2(uint16(unknownWord.length)), unknownWord, bytes32(0))
        );
        assertFalse(success);
        assertEq(bytecode.length, 0);
        assertEq(constants.length, 0);
    }

    /// Direct call to extern() on the base contract with the intInc opcode.
    function testRainlangReferenceExternExternDirect() external {
        RainlangReferenceExtern ext = new RainlangReferenceExtern();

        ExternDispatchV2 dispatch = LibExtern.encodeExternDispatch(OP_INDEX_INCREMENT, OperandV2.wrap(0));

        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(2e66, -66)));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(3e66, -66)));

        StackItem[] memory outputs = ext.extern(dispatch, inputs);
        assertEq(outputs.length, 2);
        assertEq(StackItem.unwrap(outputs[0]), Float.unwrap(LibDecimalFloat.packLossless(3e66, -66)));
        assertEq(StackItem.unwrap(outputs[1]), Float.unwrap(LibDecimalFloat.packLossless(4e66, -66)));
    }

    /// Direct call to externIntegrity() with a valid opcode. Verifies the base
    /// contract dispatch returns the same result as calling the library directly.
    /// forge-config: default.fuzz.runs = 100
    function testRainlangReferenceExternIntegrityDirect(
        uint16 operand,
        uint256 expectedInputs,
        uint256 expectedOutputs
    ) external {
        RainlangReferenceExtern ext = new RainlangReferenceExtern();

        OperandV2 op = OperandV2.wrap(bytes32(uint256(operand)));
        ExternDispatchV2 dispatch = LibExtern.encodeExternDispatch(OP_INDEX_INCREMENT, op);

        (uint256 actualInputs, uint256 actualOutputs) = ext.externIntegrity(dispatch, expectedInputs, expectedOutputs);
        (uint256 libInputs, uint256 libOutputs) = LibExternOpIntInc.integrity(op, expectedInputs, expectedOutputs);
        assertEq(actualInputs, libInputs);
        assertEq(actualOutputs, libOutputs);
    }

    /// Out-of-range opcode wraps via mod in extern(). RainlangReferenceExtern
    /// has 1 opcode, so any opcode should mod to 0 (intInc).
    function testRainlangReferenceExternExternModWrap(uint16 opcode) external {
        vm.assume(opcode >= 1);
        RainlangReferenceExtern ext = new RainlangReferenceExtern();

        ExternDispatchV2 dispatch = LibExtern.encodeExternDispatch(uint256(opcode), OperandV2.wrap(0));

        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(5e66, -66)));

        StackItem[] memory outputs = ext.extern(dispatch, inputs);
        assertEq(outputs.length, 1);
        assertEq(StackItem.unwrap(outputs[0]), Float.unwrap(LibDecimalFloat.packLossless(6e66, -66)));
    }

    /// Test the inc library directly. The run function should increment every
    /// value it is passed by 1.
    /// forge-config: default.fuzz.runs = 100
    function testRainlangReferenceExternIntIncRun(OperandV2 operand, StackItem[] memory inputs) external pure {
        StackItem[] memory expectedOutputs = new StackItem[](inputs.length);
        for (uint256 i = 0; i < inputs.length; i++) {
            inputs[i] = StackItem.wrap(
                bytes32(bound(uint256(StackItem.unwrap(inputs[i])), 0, uint256(int256(type(int128).max))))
            );
            Float a = Float.wrap(StackItem.unwrap(inputs[i]));
            a = a.add(LibDecimalFloat.packLossless(1e37, -37));
            expectedOutputs[i] = StackItem.wrap(Float.unwrap(a));
        }

        StackItem[] memory actualOutputs = LibExternOpIntInc.run(operand, inputs);
        assertEq(actualOutputs.length, expectedOutputs.length);
        for (uint256 i = 0; i < actualOutputs.length; i++) {
            assertEq(StackItem.unwrap(actualOutputs[i]), StackItem.unwrap(expectedOutputs[i]));
        }
    }

    /// Test the inc library directly. The integrity function should return the
    /// same inputs and outputs.
    /// forge-config: default.fuzz.runs = 100
    function testRainlangReferenceExternIntIncIntegrity(OperandV2 operand, uint256 inputs, uint256 outputs)
        external
        pure
    {
        (uint256 calcInputs, uint256 calcOutputs) = LibExternOpIntInc.integrity(operand, inputs, outputs);
        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, inputs);
    }
}
