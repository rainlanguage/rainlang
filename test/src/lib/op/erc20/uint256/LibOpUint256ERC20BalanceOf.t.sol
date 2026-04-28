// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {IntegrityCheckState} from "../../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibOpUint256ERC20BalanceOf} from "../../../../../../src/lib/op/erc20/uint256/LibOpUint256ERC20BalanceOf.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {UnexpectedOperand} from "../../../../../../src/error/ErrParse.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {NotAnAddress} from "../../../../../../src/error/ErrRainType.sol";
import {LibTestCast} from "test/lib/typecast/LibTestCast.sol";
import {LibBytes32Array} from "rain.solmem/lib/LibBytes32Array.sol";

/// @title LibOpUint256ERC20BalanceOfTest
/// @notice Test the opcode for getting the balance of an erc20 token.
contract LibOpUint256ERC20BalanceOfTest is OpTest {
    using LibTestCast for StackItem[];
    using LibBytes32Array for bytes32[];

    function testOpERC20BalanceOfIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpUint256ERC20BalanceOf.integrity(state, operand);

        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    function testOpERC20BalanceOfRun(address token, address account, uint256 balance, uint16 operandData) external {
        assumeEtchable(token);
        vm.etch(token, hex"fe");

        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(token))));
        inputs[1] = StackItem.wrap(bytes32(uint256(uint160(account))));
        OperandV2 operand = LibOperand.build(2, 1, operandData);

        vm.mockCall(token, abi.encodeWithSelector(IERC20.balanceOf.selector, account), abi.encode(balance));
        // called once for reference, once for run
        vm.expectCall(token, abi.encodeWithSelector(IERC20.balanceOf.selector, account), 2);

        opReferenceCheck(
            opTestDefaultInterpreterState(),
            operand,
            LibOpUint256ERC20BalanceOf.referenceFn,
            LibOpUint256ERC20BalanceOf.integrity,
            LibOpUint256ERC20BalanceOf.run,
            inputs
        );
    }

    /// Test the eval of balanceOf parsed from a string.
    function testOpERC20BalanceOfEvalHappy(uint256 balance) external {
        vm.mockCall(
            address(0xdeadbeef),
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(0xdeadc0de)),
            abi.encode(balance)
        );
        checkHappy("_: uint256-erc20-balance-of(0xdeadbeef 0xdeadc0de);", bytes32(balance), "0xdeadbeef 0xdeadc0de");
    }

    /// Test that a balanceOf with bad inputs fails integrity.
    function testOpERC20BalanceOfEvalZeroInputs() external {
        checkBadInputs("_: uint256-erc20-balance-of();", 0, 2, 0);
    }

    function testOpERC20BalanceOfEvalOneInput() external {
        checkBadInputs("_: uint256-erc20-balance-of(0xdeadbeef);", 1, 2, 1);
    }

    function testOpERC20BalanceOfEvalThreeInputs() external {
        checkBadInputs("_: uint256-erc20-balance-of(0xdeadbeef 0xdeadc0de 0xdeadc0de);", 3, 2, 3);
    }

    function testOpERC20BalanceOfEvalZeroOutputs() external {
        checkBadOutputs(": uint256-erc20-balance-of(0xdeadbeef 0xdeadc0de);", 2, 1, 0);
    }

    function testOpERC20BalanceOfEvalTwoOutputs() external {
        checkBadOutputs("_ _: uint256-erc20-balance-of(0xdeadbeef 0xdeadc0de);", 2, 1, 2);
    }

    /// Test that non-address token input reverts.
    function testOpUint256ERC20BalanceOfNotAnAddressToken(uint256 token) external {
        // Casting to `uint160` is intentional to detect non-address values.
        //forge-lint: disable-next-line(unsafe-typecast)
        vm.assume(token != uint256(uint160(token)));
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(token));
        inputs[1] = StackItem.wrap(bytes32(uint256(uint160(address(0xdeadc0de)))));
        OperandV2 operand = LibOperand.build(2, 1, 0);
        vm.expectRevert(abi.encodeWithSelector(NotAnAddress.selector, token));
        this.externalRun(operand, inputs);
    }

    /// Test that non-address account input reverts.
    function testOpUint256ERC20BalanceOfNotAnAddressAccount(uint256 account) external {
        // Casting to `uint160` is intentional to detect non-address values.
        //forge-lint: disable-next-line(unsafe-typecast)
        vm.assume(account != uint256(uint160(account)));
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(0xdeadbeef)))));
        inputs[1] = StackItem.wrap(bytes32(account));
        OperandV2 operand = LibOperand.build(2, 1, 0);
        vm.expectRevert(abi.encodeWithSelector(NotAnAddress.selector, account));
        this.externalRun(operand, inputs);
    }

    function externalRun(OperandV2 operand, StackItem[] memory inputs) external view {
        LibOpUint256ERC20BalanceOf.run(opTestDefaultInterpreterState(), operand, inputs.asBytes32Array().dataPointer());
    }

    /// Test that operand is disallowed.
    function testOpERC20BalanceOfEvalOperandDisallowed() external {
        checkUnhappyParse(
            "_: uint256-erc20-balance-of<0>(0xdeadbeef 0xdeadc0de);", abi.encodeWithSelector(UnexpectedOperand.selector)
        );
    }
}
