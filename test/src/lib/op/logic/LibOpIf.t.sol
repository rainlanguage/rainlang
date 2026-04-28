// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest, UnexpectedOperand} from "test/abstract/OpTest.sol";
import {LibOpIf} from "../../../../../src/lib/op/logic/LibOpIf.sol";
import {IntegrityCheckState, BadOpInputsLength} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {InterpreterState} from "../../../../../src/lib/state/LibInterpreterState.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";

contract LibOpIfTest is OpTest {
    /// Directly test the integrity logic of LibOpIf. No matter the
    /// operand inputs, the calc inputs must be 3, and the calc outputs must be
    /// 1.
    function testOpIfIntegrityHappy(IntegrityCheckState memory state, uint8 inputs, uint8 outputs, uint16 operandData)
        external
        pure
    {
        inputs = uint8(bound(inputs, 0, 0x0F));
        outputs = uint8(bound(outputs, 0, 0x0F));
        (uint256 calcInputs, uint256 calcOutputs) =
            LibOpIf.integrity(state, LibOperand.build(inputs, outputs, operandData));

        // The inputs from the operand are ignored. The op is always 2 inputs.
        assertEq(calcInputs, 3);
        assertEq(calcOutputs, 1);
    }

    /// Directly test the runtime logic of LibOpIf.
    function testOpIfRun(StackItem a, StackItem b, StackItem c) external view {
        InterpreterState memory state = opTestDefaultInterpreterState();
        StackItem[] memory inputs = new StackItem[](3);
        inputs[0] = a;
        inputs[1] = b;
        inputs[2] = c;
        OperandV2 operand = LibOperand.build(uint8(inputs.length), 1, 0);
        opReferenceCheck(state, operand, LibOpIf.referenceFn, LibOpIf.integrity, LibOpIf.run, inputs);
    }

    /// Test the eval of if parsed from a string. Tests 3 inputs. The first input
    /// is 0, the second input is 1, the third input is 2.
    function testOpIfEval3InputsFirstZeroSecondOneThirdTwo() external view {
        checkHappy("_: if(0 1 2);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "");
    }

    /// Test the eval of if parsed from a string. Tests 3 inputs. The first input
    /// is 1, the second input is 2, the third input is 3.
    function testOpIfEval3InputsFirstOneSecondTwoThirdThree() external view {
        checkHappy("_: if(1 2 3);", Float.unwrap(LibDecimalFloat.packLossless(2, 0)), "");
    }

    /// Test the eval of if parsed from a string. Tests 3 inputs. The first input
    /// is 0, the second input is 0, the third input is 3.
    function testOpIfEval3InputsFirstZeroSecondZeroThirdThree() external view {
        checkHappy("_: if(0 0 3);", Float.unwrap(LibDecimalFloat.packLossless(3, 0)), "");
    }

    /// Test the eval of if parsed from a string. Tests 3 inputs. The first input
    /// is 1, the second input is 0, the third input is 3.
    function testOpIfEval3InputsFirstOneSecondZeroThirdThree() external view {
        checkHappy("_: if(1 0 3);", 0, "");
    }

    /// Test the eval of if parsed from a string. Tests 3 inputs. The first input
    /// is 0, the second input is 1, the third input is 0.
    function testOpIfEval3InputsFirstZeroSecondOneThirdZero() external view {
        checkHappy("_: if(0 1 0);", 0, "");
    }

    /// Test the eval of if parsed from a string. Tests 3 inputs. The first input
    /// is 0, the second input is 0, the third input is 1.
    function testOpIfEval3InputsFirstZeroSecondZeroThirdOne() external view {
        checkHappy("_: if(0 0 1);", Float.unwrap(LibDecimalFloat.packLossless(1, 0)), "");
    }

    /// Test the eval of if parsed from a string. Tests 3 inputs. The first input
    /// is 2, the second input is 3, the third input is 4.
    function testOpIfEval3InputsFirstTwoSecondThreeThirdFour() external view {
        checkHappy("_: if(2 3 4);", Float.unwrap(LibDecimalFloat.packLossless(3, 0)), "");
    }

    /// Test the eval of if parsed from a string. Tests 3 inputs. The first input
    /// is 2, the second input is 0, the third input is 4.
    function testOpIfEval3InputsFirstTwoSecondZeroThirdFour() external view {
        checkHappy("_: if(2 0 4);", 0, "");
    }

    /// Test that 0e5 is false, because exponents on zero are still false.
    function testOpIfEvalZeroExponent() external view {
        checkHappy("_: if(0e5 5 50);", Float.unwrap(LibDecimalFloat.packLossless(50, 0)), "");
    }

    /// Strings behave pretty weirdly, and aren't really supported because
    /// conditionals assume numeric inputs. We can demonstrate some of the
    /// weirdness in testing.
    function testOpIfEvalEmptyStringTruthy() external view {
        /// Empty string is true, because all strings are true.
        checkHappy("_: if(\"\" 5 50);", Float.unwrap(LibDecimalFloat.packLossless(5, 0)), "");
        /// "foo" is also true, because all strings are true.
        checkHappy("_: if(\"foo\" 5 50);", Float.unwrap(LibDecimalFloat.packLossless(5, 0)), "");
        /// "foos" is true, because all strings are true.
        checkHappy("_: if(\"foos\" 5 50);", Float.unwrap(LibDecimalFloat.packLossless(5, 0)), "");
    }

    /// Test that an if without inputs fails integrity check.
    function testOpIfEvalFail0Inputs() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 0, 3, 0));
        bytes memory bytecode = I_DEPLOYER.parse2("_: if();");
        (bytecode);
    }

    /// Test that an if with 1 input fails integrity check.
    function testOpIfEvalFail1Input() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 1, 3, 1));
        bytes memory bytecode = I_DEPLOYER.parse2("_: if(0x00);");
        (bytecode);
    }

    /// Test that an if with 2 inputs fails integrity check.
    function testOpIfEvalFail2Inputs() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 2, 3, 2));
        bytes memory bytecode = I_DEPLOYER.parse2("_: if(0x00 0x00);");
        (bytecode);
    }

    /// Test that an if with 4 inputs fails integrity check.
    function testOpIfEvalFail4Inputs() public {
        vm.expectRevert(abi.encodeWithSelector(BadOpInputsLength.selector, 4, 3, 4));
        bytes memory bytecode = I_DEPLOYER.parse2("_: if(0x00 0x00 0x00 0x00);");
        (bytecode);
    }

    function testOpIfEvalZeroOutputs() external {
        checkBadOutputs(": if(5 0 0);", 3, 1, 0);
    }

    function testOpIfEvalTwoOutputs() external {
        checkBadOutputs("_ _: if(5 0 0);", 3, 1, 2);
    }

    /// Test that operand is disallowed.
    function testOpIfEvalOperandDisallowed() external {
        checkUnhappyParse("_: if<0>(1 2 3);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
