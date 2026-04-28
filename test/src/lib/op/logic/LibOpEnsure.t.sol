// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {ExcessRHSItems} from "../../../../../src/error/ErrParse.sol";
import {LibParseError} from "../../../../../src/lib/parse/LibParseError.sol";
import {LibOpEnsure} from "../../../../../src/lib/op/logic/LibOpEnsure.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibIntOrAString, IntOrAString} from "rain.intorastring/lib/LibIntOrAString.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";

contract LibOpEnsureTest is OpTest {
    using LibDecimalFloat for Float;

    /// Directly test the integrity logic of LibOpEnsure. This tests the
    /// happy path where there is at least one input.
    function testOpEnsureIntegrityHappy(
        IntegrityCheckState memory state,
        uint8 inputs,
        uint8 outputs,
        uint16 operandData
    ) external pure {
        inputs = uint8(bound(inputs, 0, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpEnsure.integrity(state, LibOperand.build(inputs, outputs, operandData));
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 0);
    }

    /// Directly test the integrity logic of LibOpEnsure. This tests the
    /// unhappy path where there are no inputs.
    function testOpEnsureIntegrityUnhappy(IntegrityCheckState memory state) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpEnsure.integrity(state, OperandV2.wrap(0));
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 0);
    }

    /// Directly test the run logic of LibOpEnsure.
    function testOpEnsureRun(StackItem condition, string memory reason) external {
        vm.assume(bytes(reason).length <= 31);
        if (Float.wrap(StackItem.unwrap(condition)).isZero()) {
            vm.expectRevert(bytes(reason));
        }

        this.internalTestOpEnsureRun(condition, reason);
    }

    function internalTestOpEnsureRun(StackItem condition, string memory reason) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = condition;
        inputs[1] = StackItem.wrap(bytes32(IntOrAString.unwrap(LibIntOrAString.fromStringV3(reason))));

        OperandV2 operand = LibOperand.build(2, 0, 0);
        opReferenceCheck(state, operand, LibOpEnsure.referenceFn, LibOpEnsure.integrity, LibOpEnsure.run, inputs);
    }

    /// Test the eval of `ensure` parsed from a string. Tests zero inputs.
    function testOpEnsureEvalZero() external {
        checkBadInputs(":ensure();", 0, 2, 0);
    }

    /// Test the eval of `ensure` parsed from a string. Tests one input.
    function testOpEnsureEvalOne() external {
        checkBadInputs(":ensure(1);", 1, 2, 1);
    }

    /// Test the eval of `ensure` parsed from a string. Tests three inputs.
    function testOpEnsureEvalThree() external {
        checkBadInputs(":ensure(1 2 3);", 3, 2, 3);
    }

    /// Test the eval of `ensure` parsed from a string. Tests that ensure cannot
    /// be used on the same line as another word as it has non-one outputs.
    /// Tests ensuring with an addition on the same line.
    function testOpEnsureEvalBadOutputs() external {
        vm.expectRevert(abi.encodeWithSelector(ExcessRHSItems.selector, LibParseError.tagErrorOffset(34)));
        (bytes memory bytecode, bytes32[] memory constants) =
            I_PARSER.unsafeParse("_:ensure(1 \"always true\") add(1 1);");
        (bytecode);
        (constants);
    }

    /// Test the eval of `ensure` parsed from a string. Tests that ensure cannot
    /// be used on the same line as another word as it has non-one outputs.
    /// Tests ensuring with another ensure on the same line.
    function testOpEnsureEvalBadOutputs2() external {
        vm.expectRevert(abi.encodeWithSelector(ExcessRHSItems.selector, LibParseError.tagErrorOffset(48)));
        (bytes memory bytecode, bytes32[] memory constants) =
            I_PARSER.unsafeParse(":ensure(1 \"always true\") ensure(1 \"always true\");");
        (bytecode);
        (constants);
    }

    /// Test the eval of `ensure` parsed from a string. Tests the happy path
    /// where all inputs are nonzero.
    function testOpEnsureEvalHappy() external view {
        checkHappy(":ensure(1 \"always 1\"), _:0x01;", bytes32(uint256(1)), "1");
        checkHappy(":ensure(5 \"always 5\"), _:0x01;", bytes32(uint256(1)), "5");

        // Empty reason should be fine.
        checkHappy(":ensure(1 \"\"), _:0x01;", bytes32(uint256(1)), "");
    }

    /// Test the eval of `ensure` parsed from a string. Tests the unhappy path
    /// where the input is 0.
    function testOpEnsureEvalUnhappy() external {
        checkUnhappy(":ensure(0 \"foo\"), _:1;", "foo");

        // Empty reason should be fine.
        checkUnhappy(":ensure(0 \"\"), _:1;", "");

        // Exponents for zero should be fine (cause a revert).
        checkUnhappy(":ensure(0e18 \"foo\"), _:1;", "foo");
    }

    /// Test the eval of `ensure` parsed from a string. Tests the unhappy path
    /// where an operand is provided.
    function testOpEnsureEvalUnhappyOperand() external {
        checkUnhappyParse(":ensure<0>(1 \"foo\");", abi.encodeWithSelector(UnexpectedOperand.selector));
    }

    function testOpEnsureOneOutput() external {
        checkBadOutputs("_:ensure(1 \"foo\");", 2, 0, 1);
    }
}
