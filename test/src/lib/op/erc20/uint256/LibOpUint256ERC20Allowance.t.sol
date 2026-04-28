// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {IntegrityCheckState} from "../../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibOpUint256ERC20Allowance} from "../../../../../../src/lib/op/erc20/uint256/LibOpUint256ERC20Allowance.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {UnexpectedOperand} from "../../../../../../src/error/ErrParse.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {NotAnAddress} from "../../../../../../src/error/ErrRainType.sol";
import {LibTestCast} from "test/lib/typecast/LibTestCast.sol";
import {LibBytes32Array} from "rain.solmem/lib/LibBytes32Array.sol";

/// @title LibOpUint256ERC20AllowanceTest
/// @notice Test the opcode for getting the allowance of an erc20 token.
contract LibOpUint256ERC20AllowanceTest is OpTest {
    using LibTestCast for StackItem[];
    using LibBytes32Array for bytes32[];

    function testOpERC20AllowanceIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpUint256ERC20Allowance.integrity(state, operand);

        assertEq(calcInputs, 3);
        assertEq(calcOutputs, 1);
    }

    function testOpERC20AllowanceRun(address token, address owner, address spender, uint256 allowance) external {
        assumeEtchable(token);
        vm.etch(token, hex"fe");

        StackItem[] memory inputs = new StackItem[](3);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(token))));
        inputs[1] = StackItem.wrap(bytes32(uint256(uint160(owner))));
        inputs[2] = StackItem.wrap(bytes32(uint256(uint160(spender))));
        OperandV2 operand = LibOperand.build(3, 1, 0);

        vm.mockCall(token, abi.encodeWithSelector(IERC20.allowance.selector, owner, spender), abi.encode(allowance));
        // called once for reference, once for run
        vm.expectCall(token, abi.encodeWithSelector(IERC20.allowance.selector, owner, spender), 2);

        opReferenceCheck(
            opTestDefaultInterpreterState(),
            operand,
            LibOpUint256ERC20Allowance.referenceFn,
            LibOpUint256ERC20Allowance.integrity,
            LibOpUint256ERC20Allowance.run,
            inputs
        );
    }

    /// Test the eval of allowance parsed from a string.
    function testOpERC20AllowanceEvalHappy(uint256 allowance) external {
        vm.mockCall(
            address(0xdeadbeef),
            abi.encodeWithSelector(IERC20.allowance.selector, address(0xdeadc0de), address(0xdeaddead)),
            abi.encode(allowance)
        );
        checkHappy(
            "_: uint256-erc20-allowance(0xdeadbeef 0xdeadc0de 0xdeaddead);",
            bytes32(allowance),
            "0xdeadbeef 0xdeadc0de 0xdeaddead"
        );
    }

    /// Test that a allowance with bad inputs fails integrity.
    function testOpERC20AllowanceEvalZeroInputs() external {
        checkBadInputs("_: uint256-erc20-allowance();", 0, 3, 0);
    }

    function testOpERC20AllowanceEvalOneInput() external {
        checkBadInputs("_: uint256-erc20-allowance(0xdeadbeef);", 1, 3, 1);
    }

    function testOpERC20AllowanceEvalTwoInputs() external {
        checkBadInputs("_: uint256-erc20-allowance(0xdeadbeef 0xdeadc0de);", 2, 3, 2);
    }

    function testOpERC20AllowanceEvalFourInputs() external {
        checkBadInputs("_: uint256-erc20-allowance(0xdeadbeef 0xdeadc0de 0xdeaddead 0xdeaddead);", 4, 3, 4);
    }

    function testOpERC20AllowanceEvalZeroOutputs() external {
        checkBadOutputs(": uint256-erc20-allowance(0xdeadbeef 0xdeadc0de 0xdeaddead);", 3, 1, 0);
    }

    function testOpERC20AllowanceEvalTwoOutputs() external {
        checkBadOutputs("_ _: uint256-erc20-allowance(0xdeadbeef 0xdeadc0de 0xdeaddead);", 3, 1, 2);
    }

    /// Test that non-address token input reverts.
    function testOpUint256ERC20AllowanceNotAnAddressToken(uint256 token) external {
        // Casting to `uint160` is intentional to detect non-address values.
        //forge-lint: disable-next-line(unsafe-typecast)
        vm.assume(token != uint256(uint160(token)));
        StackItem[] memory inputs = new StackItem[](3);
        inputs[0] = StackItem.wrap(bytes32(token));
        inputs[1] = StackItem.wrap(bytes32(uint256(uint160(address(0xdeadc0de)))));
        inputs[2] = StackItem.wrap(bytes32(uint256(uint160(address(0xdeaddead)))));
        OperandV2 operand = LibOperand.build(3, 1, 0);
        vm.expectRevert(abi.encodeWithSelector(NotAnAddress.selector, token));
        this.externalRun(operand, inputs);
    }

    /// Test that non-address owner input reverts.
    function testOpUint256ERC20AllowanceNotAnAddressOwner(uint256 owner) external {
        // Casting to `uint160` is intentional to detect non-address values.
        //forge-lint: disable-next-line(unsafe-typecast)
        vm.assume(owner != uint256(uint160(owner)));
        StackItem[] memory inputs = new StackItem[](3);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(0xdeadbeef)))));
        inputs[1] = StackItem.wrap(bytes32(owner));
        inputs[2] = StackItem.wrap(bytes32(uint256(uint160(address(0xdeaddead)))));
        OperandV2 operand = LibOperand.build(3, 1, 0);
        vm.expectRevert(abi.encodeWithSelector(NotAnAddress.selector, owner));
        this.externalRun(operand, inputs);
    }

    /// Test that non-address spender input reverts.
    function testOpUint256ERC20AllowanceNotAnAddressSpender(uint256 spender) external {
        // Casting to `uint160` is intentional to detect non-address values.
        //forge-lint: disable-next-line(unsafe-typecast)
        vm.assume(spender != uint256(uint160(spender)));
        StackItem[] memory inputs = new StackItem[](3);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(0xdeadbeef)))));
        inputs[1] = StackItem.wrap(bytes32(uint256(uint160(address(0xdeadc0de)))));
        inputs[2] = StackItem.wrap(bytes32(spender));
        OperandV2 operand = LibOperand.build(3, 1, 0);
        vm.expectRevert(abi.encodeWithSelector(NotAnAddress.selector, spender));
        this.externalRun(operand, inputs);
    }

    function externalRun(OperandV2 operand, StackItem[] memory inputs) external view {
        LibOpUint256ERC20Allowance.run(opTestDefaultInterpreterState(), operand, inputs.asBytes32Array().dataPointer());
    }

    /// Test that operand is disallowed.
    function testOpERC20AllowanceEvalOperandDisallowed() external {
        checkUnhappyParse(
            "_: uint256-erc20-allowance<0>(0xdeadbeef 0xdeadc0de 0xdeaddead);",
            abi.encodeWithSelector(UnexpectedOperand.selector)
        );
    }
}
