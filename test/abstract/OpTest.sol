// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

// Exported for convenience in op tests.
//forge-lint: disable-next-line(unused-import)
import {Test, stdError} from "forge-std/Test.sol";
import {LibMemCpy} from "rain.solmem/lib/LibMemCpy.sol";
import {MemoryKV} from "rain.lib.memkv/lib/LibMemoryKV.sol";
import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {LibPointer, Pointer} from "rain.solmem/lib/LibPointer.sol";

import {RainlangExpressionDeployerDeploymentTest} from "./RainlangExpressionDeployerDeploymentTest.sol";
import {LibInterpreterState, InterpreterState} from "../../src/lib/state/LibInterpreterState.sol";
import {LibInterpreterStateFingerprint} from "../lib/state/LibInterpreterStateFingerprint.sol";
import {IntegrityCheckState, LibIntegrityCheck} from "../../src/lib/integrity/LibIntegrityCheck.sol";

import {LibContext} from "rain.interpreter.interface/lib/caller/LibContext.sol";
import {UnexpectedOperand} from "../../src/error/ErrParse.sol";
import {BadOpInputsLength, BadOpOutputsLength} from "../../src/lib/integrity/LibIntegrityCheck.sol";
import {
    OperandV2,
    SourceIndexV2,
    IInterpreterStoreV3,
    EvalV4,
    StackItem
} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {FullyQualifiedNamespace, StateNamespace} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV4.sol";
import {LibNamespace} from "rain.interpreter.interface/lib/ns/LibNamespace.sol";
import {ExponentOverflow, CoefficientOverflow} from "rain.math.float/error/ErrDecimalFloat.sol";
import {LibTOFUTokenDecimals} from "rain.tofu.erc20-decimals/lib/LibTOFUTokenDecimals.sol";

import {console2} from "forge-std/console2.sol";
import {Float, LibDecimalFloat} from "rain.math.float/lib/LibDecimalFloat.sol";

bytes32 constant PRE = keccak256(abi.encodePacked("pre"));
bytes32 constant POST = keccak256(abi.encodePacked("post"));

abstract contract OpTest is RainlangExpressionDeployerDeploymentTest {
    using LibInterpreterState for InterpreterState;
    using LibInterpreterStateFingerprint for InterpreterState;
    using LibUint256Array for uint256[];
    using LibPointer for Pointer;

    struct ReferenceCheckPointers {
        Pointer pre;
        Pointer post;
        Pointer stackTop;
        Pointer expectedStackTopAfter;
        // Initially this won't be populated. It will be populated by the
        // real function call.
        Pointer actualStackTopAfter;
    }

    function assumeEtchable(address account) internal view {
        assumeEtchable(account, address(0));
    }

    function assumeEtchable(address account, address expression) internal view {
        assumeNotPrecompile(account);
        vm.assume(account != address(I_DEPLOYER));
        vm.assume(account != address(I_INTERPRETER));
        vm.assume(account != address(I_STORE));
        vm.assume(account != address(I_PARSER));
        vm.assume(account != address(this));
        vm.assume(account != address(vm));
        vm.assume(account != address(expression));
        // The console.
        vm.assume(account != address(0x000000000000000000636F6e736F6c652e6c6f67));
        vm.assume(account != address(LibTOFUTokenDecimals.TOFU_DECIMALS_DEPLOYMENT));
    }

    function opTestDefaultIngegrityCheckState() internal pure returns (IntegrityCheckState memory) {
        return IntegrityCheckState(0, 0, 0, new bytes32[](0), 0, "");
    }

    function opTestDefaultInterpreterState() internal view returns (InterpreterState memory) {
        return InterpreterState(
            new Pointer[](0),
            new bytes32[](0),
            0,
            MemoryKV.wrap(0),
            // Treat ourselves as the sender as we eval internally to directly
            // test the opcode logic.
            LibNamespace.qualifyNamespace(StateNamespace.wrap(0), address(this)),
            IInterpreterStoreV3(address(I_STORE)),
            new bytes32[][](0),
            "",
            ""
        );
    }

    function opReferenceCheckIntegrity(
        function(IntegrityCheckState memory, OperandV2) view returns (uint256, uint256) integrityFn,
        OperandV2 operand,
        bytes32[] memory constants,
        StackItem[] memory inputs
    ) internal view returns (uint256) {
        IntegrityCheckState memory integrityState = LibIntegrityCheck.newState("", 0, constants);
        (uint256 calcInputs, uint256 calcOutputs) = integrityFn(integrityState, operand);
        assertEq(calcInputs, inputs.length, "inputs length");
        assertEq(calcInputs, uint256(OperandV2.unwrap(operand) >> 0x10) & 0x0F, "operand inputs");
        assertEq(calcOutputs, uint256(OperandV2.unwrap(operand) >> 0x14), "operand outputs");
        return calcOutputs;
    }

    function opReferenceCheckPointers(StackItem[] memory inputs, uint256 calcOutputs)
        internal
        pure
        returns (ReferenceCheckPointers memory pointers)
    {
        {
            uint256 inputsLength = inputs.length;
            Pointer prePointer;
            Pointer postPointer;
            Pointer stackTop;
            Pointer expectedStackTopAfter;
            assembly ("memory-safe") {
                let headroom := 0x20
                if gt(calcOutputs, inputsLength) {
                    headroom := add(headroom, mul(sub(calcOutputs, inputsLength), 0x20))
                }
                postPointer := mload(0x40)
                stackTop := add(postPointer, headroom)
                // Copy the inputs to the stack.
                let readCursor := add(inputs, 0x20)
                let writeCursor := stackTop
                prePointer := add(stackTop, mul(inputsLength, 0x20))
                for {} lt(writeCursor, prePointer) {
                    writeCursor := add(writeCursor, 0x20)
                    readCursor := add(readCursor, 0x20)
                } { mstore(writeCursor, mload(readCursor)) }

                expectedStackTopAfter := sub(add(stackTop, mul(inputsLength, 0x20)), mul(calcOutputs, 0x20))
                mstore(0x40, add(prePointer, 0x20))
            }
            pointers.pre = prePointer;
            pointers.pre.unsafeWriteWord(PRE);
            pointers.post = postPointer;
            pointers.post.unsafeWriteWord(POST);
            pointers.stackTop = stackTop;
            pointers.expectedStackTopAfter = expectedStackTopAfter;

            uint256 inputsDataPointer;
            assembly ("memory-safe") {
                inputsDataPointer := add(inputs, 0x20)
            }
            LibMemCpy.unsafeCopyWordsTo(Pointer.wrap(inputsDataPointer), pointers.stackTop, inputs.length);
        }
    }

    function opReferenceCheckActual(
        InterpreterState memory state,
        OperandV2 operand,
        ReferenceCheckPointers memory pointers,
        function(InterpreterState memory, OperandV2, Pointer) view returns (Pointer) runFn
    ) internal view {
        bytes32 stateFingerprintBefore = state.fingerprint();
        pointers.actualStackTopAfter = runFn(state, operand, pointers.stackTop);
        bytes32 stateFingerprintAfter = state.fingerprint();

        assertEq(stateFingerprintBefore, stateFingerprintAfter, "state fingerprint");
    }

    function opReferenceCheckExpectations(
        InterpreterState memory state,
        OperandV2 operand,
        function(InterpreterState memory, OperandV2, StackItem[] memory) view returns (StackItem[] memory) referenceFn,
        ReferenceCheckPointers memory pointers,
        StackItem[] memory inputs,
        uint256 calcOutputs
    ) internal view {
        StackItem[] memory expectedOutputs = referenceFn(state, operand, inputs);
        assertEq(expectedOutputs.length, calcOutputs, "expected outputs length");

        assertEq(
            Pointer.unwrap(pointers.actualStackTopAfter),
            Pointer.unwrap(pointers.expectedStackTopAfter),
            "stack top after"
        );
        assertEq(PRE, pointers.pre.unsafeReadWord(), "pre");
        for (uint256 i = 0; i < expectedOutputs.length; i++) {
            assertEq(StackItem.unwrap(expectedOutputs[i]), pointers.expectedStackTopAfter.unsafeReadWord(), "value");
            pointers.expectedStackTopAfter = pointers.expectedStackTopAfter.unsafeAddWord();
        }
        assertEq(POST, pointers.post.unsafeReadWord(), "post");
    }

    function opReferenceCheck(
        InterpreterState memory state,
        OperandV2 operand,
        function(InterpreterState memory, OperandV2, StackItem[] memory) view returns (StackItem[] memory) referenceFn,
        function(IntegrityCheckState memory, OperandV2) view returns (uint256, uint256) integrityFn,
        function(InterpreterState memory, OperandV2, Pointer) view returns (Pointer) runFn,
        StackItem[] memory inputs
    ) internal view {
        uint256 calcOutputs = opReferenceCheckIntegrity(integrityFn, operand, state.constants, inputs);
        ReferenceCheckPointers memory pointers = opReferenceCheckPointers(inputs, calcOutputs);

        opReferenceCheckActual(state, operand, pointers, runFn);
        opReferenceCheckExpectations(state, operand, referenceFn, pointers, inputs, calcOutputs);
    }

    function parseAndEval(bytes memory rainString, bytes32[][] memory context)
        internal
        view
        returns (StackItem[] memory, bytes32[] memory)
    {
        bytes memory bytecode = I_DEPLOYER.parse2(rainString);

        (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: LibNamespace.qualifyNamespace(StateNamespace.wrap(0), address(this)),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: context,
                inputs: new StackItem[](0),
                stateOverlay: new bytes32[](0)
            })
        );
        return (stack, kvs);
    }

    /// 90%+ of the time we don't need to pass a context. This overloads a
    /// simplified interface to parse and eval.
    function parseAndEval(bytes memory rainString) internal view returns (StackItem[] memory, bytes32[] memory) {
        return parseAndEval(rainString, LibContext.build(new bytes32[][](0), new SignedContextV1[](0)));
    }

    function checkHappy(bytes memory rainString, bytes32 expectedValue, string memory errString) internal view {
        StackItem[] memory expectedStack = new StackItem[](1);
        expectedStack[0] = StackItem.wrap(expectedValue);
        checkHappy(rainString, expectedStack, errString);
    }

    function checkHappy(bytes memory rainString, StackItem[] memory expectedStack, string memory errString)
        internal
        view
    {
        checkHappy(rainString, LibContext.build(new bytes32[][](0), new SignedContextV1[](0)), expectedStack, errString);
    }

    function checkHappy(
        bytes memory rainString,
        bytes32[][] memory context,
        StackItem[] memory expectedStack,
        string memory errString
    ) internal view {
        (StackItem[] memory stack, bytes32[] memory kvs) = parseAndEval(rainString, context);

        assertEq(stack.length, expectedStack.length, errString);
        for (uint256 i = 0; i < expectedStack.length; i++) {
            (int256 signedCoefficient, int256 exponent) = LibDecimalFloat.unpack(Float.wrap(StackItem.unwrap(stack[i])));
            console2.logInt(signedCoefficient);
            console2.logInt(exponent);
            (signedCoefficient, exponent) = LibDecimalFloat.unpack(Float.wrap(StackItem.unwrap(expectedStack[i])));
            console2.logInt(signedCoefficient);
            console2.logInt(exponent);
            assertEq(StackItem.unwrap(stack[i]), StackItem.unwrap(expectedStack[i]), errString);
        }
        assertEq(kvs.length, 0);
    }

    function checkHappyKVs(bytes memory rainString, bytes32[] memory expectedKVs, string memory errString)
        internal
        view
    {
        (StackItem[] memory stack, bytes32[] memory kvs) = parseAndEval(rainString);

        assertEq(stack.length, 0);
        assertEq(kvs.length, expectedKVs.length, errString);
        for (uint256 i = 0; i < expectedKVs.length; i++) {
            assertEq(kvs[i], expectedKVs[i], errString);
        }
    }

    function checkUnhappyOverflow(bytes memory rainString, int256 signedCoefficient, int256 exponent) internal {
        checkUnhappy(rainString, abi.encodeWithSelector(ExponentOverflow.selector, signedCoefficient, exponent));
    }

    function checkUnhappyCoefficientOverflow(bytes memory rainString, int256 signedCoefficient, int256 exponent)
        internal
    {
        checkUnhappy(rainString, abi.encodeWithSelector(CoefficientOverflow.selector, signedCoefficient, exponent));
    }

    function checkUnhappy(bytes memory rainString, bytes memory err) internal {
        bytes memory bytecode = I_DEPLOYER.parse2(rainString);
        vm.expectRevert(err);
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
        (stack, kvs);
    }

    function checkUnhappyParse2(bytes memory rainString, bytes memory err) internal {
        vm.expectRevert(err);
        bytes memory bytecode = I_DEPLOYER.parse2(rainString);
        (bytecode);
    }

    function checkUnhappyParse(bytes memory rainString, bytes memory err) internal {
        vm.expectRevert(err);
        (bytes memory bytecode, bytes32[] memory constants) = I_PARSER.unsafeParse(rainString);
        (bytecode);
        (constants);
    }

    function checkBadInputs(bytes memory rainString, uint256 opIndex, uint256 calcInputs, uint256 bytecodeInputs)
        internal
    {
        checkUnhappyParse2(
            rainString, abi.encodeWithSelector(BadOpInputsLength.selector, opIndex, calcInputs, bytecodeInputs)
        );
    }

    function checkBadOutputs(bytes memory rainString, uint256 opIndex, uint256 calcOutputs, uint256 bytecodeOutputs)
        internal
    {
        checkUnhappyParse2(
            rainString, abi.encodeWithSelector(BadOpOutputsLength.selector, opIndex, calcOutputs, bytecodeOutputs)
        );
    }

    function checkDisallowedOperand(bytes memory rainString) internal {
        vm.expectRevert(abi.encodeWithSelector(UnexpectedOperand.selector));
        (bytes memory bytecode, bytes32[] memory constants) = I_PARSER.unsafeParse(rainString);
        (bytecode);
        (constants);
    }
}
