// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {MemoryKV} from "rain.lib.memkv/lib/LibMemoryKV.sol";

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpAny} from "../../../../../src/lib/op/logic/LibOpAny.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {
    IInterpreterStoreV3,
    FullyQualifiedNamespace
} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {LibInterpreterState, InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {BadOpInputsLength} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";

contract LibOpAnyTest is OpTest {
    using LibUint256Array for uint256[];

    /// Directly test the integrity logic of LibOpAny. This tests the happy
    /// path where the operand is valid.
    function testOpAnyIntegrityHappy(uint8 inputs, uint16 operandData) external pure {
        IntegrityCheckState memory state = opTestDefaultIngegrityCheckState();
        inputs = uint8(bound(uint256(inputs), 1, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) = LibOpAny.integrity(state, LibOperand.build(inputs, 1, operandData));

        assertEq(calcInputs, inputs);
        assertEq(calcOutputs, 1);
    }

    /// Sample the gas cost of the integrity check.
    function testOpAnyIntegrityGas0() external {
        vm.pauseGasMetering();
        IntegrityCheckState memory state = IntegrityCheckState(6, 6, 6, new bytes32[](3), 9, "");
        OperandV2 operand = OperandV2.wrap(bytes32(uint256(0x50000)));
        vm.resumeGasMetering();
        // 5 inputs. Any stack index above this is fine for the state.
        (uint256 calcInputs, uint256 calcOutputs) = LibOpAny.integrity(state, operand);
        (calcInputs);
        (calcOutputs);
    }

    /// Directly test the integrity logic of LibOpAny. This tests the unhappy
    /// path where the operand is invalid due to 0 inputs.
    function testOpAnyIntegrityUnhappyZeroInputs() external pure {
        IntegrityCheckState memory state = opTestDefaultIngegrityCheckState();
        (uint256 calcInputs, uint256 calcOutputs) = LibOpAny.integrity(state, OperandV2.wrap(0));
        // Calc inputs will be minimum 1.
        assertEq(calcInputs, 1);
        assertEq(calcOutputs, 1);
    }

    function _testOpAnyRun(OperandV2 operand, StackItem[] memory inputs) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        opReferenceCheck(state, operand, LibOpAny.referenceFn, LibOpAny.integrity, LibOpAny.run, inputs);
    }

    /// Directly test the runtime logic of LibOpAny.
    function testOpAnyRun(StackItem[] memory inputs, uint16 operandData) external view {
        vm.assume(inputs.length != 0);
        vm.assume(inputs.length <= 0x0F);
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, operandData);
        this._testOpAnyRun(operand, inputs);
    }

    /// Sample the gas cost of the run function.
    function testOpAnyRunGas0() external {
        vm.pauseGasMetering();
        StackItem[][] memory stacks = new StackItem[][](1);
        stacks[0] = new StackItem[](1);
        Pointer stackTop;
        assembly ("memory-safe") {
            stackTop := add(stacks, 0x20)
        }
        InterpreterState memory state = InterpreterState(
            LibInterpreterState.stackBottoms(stacks),
            new bytes32[](0),
            0,
            MemoryKV.wrap(0),
            FullyQualifiedNamespace.wrap(0),
            IInterpreterStoreV3(address(0)),
            new bytes32[][](0),
            "",
            ""
        );
        OperandV2 operand = OperandV2.wrap(bytes32(uint256(0x10000)));
        vm.resumeGasMetering();
        // 1 inputs. Any stack index above this is fine for the state.
        LibOpAny.run(state, operand, stackTop);
    }

    /// Test the eval of any opcode parsed from a string. Tests 1 true input.
    function testOpAnyEval1TrueInput() external view {
        checkHappy("_: any(5);", bytes32(uint256(5)), "");
    }

    /// Test the eval of any opcode parsed from a string. Tests 1 false input.
    function testOpAnyEval1FalseInput() external view {
        checkHappy("_: any(0);", 0, "");
    }

    /// Test the eval of any opcode parsed from a string. Tests 2 true inputs.
    /// The first true input should be the overall result.
    function testOpAnyEval2TrueInputs() external view {
        checkHappy("_: any(5 6);", bytes32(uint256(5)), "");
    }

    /// Test the eval of any opcode parsed from a string. Tests 2 false inputs.
    function testOpAnyEval2FalseInputs() external view {
        checkHappy("_: any(0 0);", 0, "");
    }

    /// Test the eval of any opcode parsed from a string. Tests 2 inputs, one
    /// true and one false. The first true input should be the overall result.
    /// The first value is the true value.
    function testOpAnyEval2MixedInputs() external view {
        checkHappy("_: any(5 0);", bytes32(uint256(5)), "");
    }

    /// Test the eval of any opcode parsed from a string. Tests 2 inputs, one
    /// true and one false. The first true input should be the overall result.
    /// The first value is the false value.
    function testOpAnyEval2MixedInputs2() external view {
        checkHappy("_: any(0 5);", bytes32(uint256(5)), "");
    }

    /// Test 0, 5 but where the 0 has an exponent like 0e5. Shows that truthy
    /// check is float aware.
    function testOpAnyEval2MixedInputsZeroExponent() external view {
        checkHappy("_: any(0e5 5);", bytes32(uint256(5)), "");
    }

    /// Test that any without inputs fails integrity check.
    function testOpAnyEvalFail() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 0, 1, 0));
        bytes memory bytecode = I_DEPLOYER.parse2("_: any();");
        (bytecode);
    }

    function testOpAnyZeroOutputs() external {
        checkBadOutputs(": any(0);", 1, 1, 0);
    }

    function testOpAnyTwoOutputs() external {
        checkBadOutputs("_ _: any(0);", 1, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpAnyEvalOperandDisallowed() external {
        checkUnhappyParse("_: any<0>(1);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
