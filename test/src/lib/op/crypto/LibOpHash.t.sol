// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";

import {LibOpHash} from "../../../../../src/lib/op/crypto/LibOpHash.sol";
import {LibContext} from "rain.interpreter.interface/lib/caller/LibContext.sol";

import {LibPointer, Pointer} from "rain.solmem/lib/LibPointer.sol";
import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";

import {OperandV2, SourceIndexV2, EvalV4, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {FullyQualifiedNamespace} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV4.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {InterpreterState, LibInterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";

/// @title LibOpHashTest
/// @notice Test the runtime and integrity time logic of LibOpHash.
contract LibOpHashTest is OpTest {
    using LibInterpreterState for InterpreterState;
    using LibPointer for Pointer;
    using LibUint256Array for uint256[];

    /// Directly test the integrity logic of LibOpHash. This tests the happy
    /// path where the operand is valid.
    function testOpHashIntegrityHappy(IntegrityCheckState memory state, uint8 inputs, uint8 outputs, uint16 operandData)
        external
        pure
    {
        inputs = uint8(bound(inputs, 0, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        OperandV2 operand = LibOperand.build(inputs, outputs, operandData);
        (uint256 calcInputs, uint256 calcOutputs) = LibOpHash.integrity(state, operand);

        assertEq(inputs, calcInputs);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpHash.
    function testOpHashRun(StackItem[] memory inputs) external view {
        vm.assume(inputs.length <= 0x0F);
        InterpreterState memory state = opTestDefaultInterpreterState();
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(state, operand, LibOpHash.referenceFn, LibOpHash.integrity, LibOpHash.run, inputs);
    }

    /// Test the eval of a hash opcode parsed from a string. Tests 0 inputs.
    function testOpHashEval0Inputs() external view {
        checkHappy("_: hash();", keccak256(""), "");
    }

    /// Test the eval of a hash opcode parsed from a string. Tests 1 input.
    function testOpHashEval1Input() external view {
        checkHappy("_: hash(0x1234567890abcdef);", keccak256(abi.encodePacked(uint256(0x1234567890abcdef))), "");
    }

    /// Test the eval of a hash opcode parsed from a string. Tests 2 inputs that
    /// are identical to each other.
    function testOpHashEval2Inputs() external view {
        checkHappy(
            "_: hash(0x1234567890abcdef 0x1234567890abcdef);",
            keccak256(abi.encodePacked(uint256(0x1234567890abcdef), uint256(0x1234567890abcdef))),
            ""
        );
    }

    /// Test the eval of a hash opcode parsed from a string. Tests 2 inputs that
    /// are different from each other.
    function testOpHashEval2InputsDifferent() external view {
        checkHappy(
            "_: hash(0x1234567890abcdef 0xfedcba0987654321);",
            keccak256(abi.encodePacked(uint256(0x1234567890abcdef), uint256(0xfedcba0987654321))),
            ""
        );
    }

    /// Test the eval of a hash opcode parsed from a string. Tests 2 inputs and
    /// other stack items.
    function testOpHashEval2InputsOtherStack() external view {
        bytes memory bytecode = I_DEPLOYER.parse2("_ _ _: 5 hash(0x1234567890abcdef 0xfedcba0987654321) 9;");
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
        assertEq(stack.length, 3);
        assertEq(StackItem.unwrap(stack[0]), Float.unwrap(LibDecimalFloat.packLossless(9, 0)));
        assertEq(
            StackItem.unwrap(stack[1]),
            keccak256(abi.encodePacked(uint256(0x1234567890abcdef), uint256(0xfedcba0987654321)))
        );
        assertEq(StackItem.unwrap(stack[2]), Float.unwrap(LibDecimalFloat.packLossless(5, 0)));
        assertEq(kvs.length, 0);
    }

    function testOpHashZeroOutputs() external {
        checkBadOutputs(":hash();", 0, 1, 0);
    }

    function testOpHashTwoOutputs() external {
        checkBadOutputs("_ _: hash();", 0, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpHashEvalOperandDisallowed() external {
        checkUnhappyParse("_: hash<0>(1);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
