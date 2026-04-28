// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {IntegrityCheckState} from "../../../../../src/lib/integrity/LibIntegrityCheck.sol";
import {OperandV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibOpERC20TotalSupply} from "../../../../../src/lib/op/erc20/LibOpERC20TotalSupply.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {UnexpectedOperand} from "../../../../../src/error/ErrParse.sol";
import {LibOperand} from "test/lib/operand/LibOperand.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {LibDecimalFloat, Float, LossyConversionToFloat} from "rain.math.float/lib/LibDecimalFloat.sol";
import {TOFUOutcome, ITOFUTokenDecimals} from "rain.tofu.erc20-decimals/interface/ITOFUTokenDecimals.sol";
import {NotAnAddress} from "../../../../../src/error/ErrRainType.sol";
import {LibTestCast} from "test/lib/typecast/LibTestCast.sol";
import {LibBytes32Array} from "rain.solmem/lib/LibBytes32Array.sol";

/// @title LibOpERC20TotalSupplyTest
/// @notice Test the opcode for getting the total supply of an erc20 contract.
contract LibOpERC20TotalSupplyTest is OpTest {
    using LibTestCast for StackItem[];
    using LibBytes32Array for bytes32[];

    function testOpERC20TotalSupplyIntegrity(IntegrityCheckState memory state, OperandV2 operand) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpERC20TotalSupply.integrity(state, operand);

        assertEq(calcInputs, 1);
        assertEq(calcOutputs, 1);
    }

    function testOpERC20TotalSupplyRun(address account, uint256 totalSupply, uint16 operandData, uint8 decimals)
        external
    {
        assumeEtchable(account);
        vm.etch(account, hex"fe");

        (, bool lossless) = LibDecimalFloat.fromFixedDecimalLossyPacked(totalSupply, decimals);
        vm.assume(lossless);

        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(account))));
        OperandV2 operand = LibOperand.build(1, 1, operandData);

        vm.mockCall(account, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(totalSupply));
        // called once for reference, once for run
        vm.expectCall(account, abi.encodeWithSelector(IERC20.totalSupply.selector), 2);

        vm.mockCall(account, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(decimals));

        opReferenceCheck(
            opTestDefaultInterpreterState(),
            operand,
            LibOpERC20TotalSupply.referenceFn,
            LibOpERC20TotalSupply.integrity,
            LibOpERC20TotalSupply.run,
            inputs
        );
    }

    /// Test the eval of totalSupply parsed from a string.
    function testOpERC20TotalSupplyEvalHappy(uint256 totalSupply, uint8 decimals) external {
        (, bool lossless) = LibDecimalFloat.fromFixedDecimalLossyPacked(totalSupply, decimals);
        vm.assume(lossless);

        vm.mockCall(address(0xdeadbeef), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(totalSupply));
        vm.mockCall(address(0xdeadbeef), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(decimals));

        Float totalSupplyFloat = LibDecimalFloat.fromFixedDecimalLosslessPacked(totalSupply, decimals);

        checkHappy("_: erc20-total-supply(0xdeadbeef);", Float.unwrap(totalSupplyFloat), "0xdeadbeef 0xdeadc0de");
    }

    /// Test overflow of totalSupply.
    function testOpERC20TotalSupplyEvalOverflow(uint256 totalSupply, uint8 decimals) external {
        (int256 signedCoefficient, int256 exponent, bool lossless) =
            LibDecimalFloat.fromFixedDecimalLossy(totalSupply, decimals);
        vm.assume(!lossless);
        (, bool losslessPack) = LibDecimalFloat.packLossy(signedCoefficient, exponent);
        vm.assume(!losslessPack);

        vm.mockCall(address(0xdeadbeef), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(totalSupply));
        vm.mockCall(address(0xdeadbeef), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(decimals));
        checkUnhappy(
            "_: erc20-total-supply(0xdeadbeef);",
            abi.encodeWithSelector(LossyConversionToFloat.selector, signedCoefficient, exponent)
        );
    }

    /// Test that a totalSupply with bad inputs fails integrity.
    function testOpERC20TotalSupplyEvalZeroInputs() external {
        checkBadInputs("_: erc20-total-supply();", 0, 1, 0);
    }

    function testOpERC20TotalSupplyEvalTwoInputs() external {
        checkBadInputs("_: erc20-total-supply(0xdeadbeef 0xdeadc0de);", 2, 1, 2);
    }

    function testOpERC20TotalSupplyEvalZeroOutputs() external {
        checkBadOutputs(": erc20-total-supply(0xdeadbeef);", 1, 1, 0);
    }

    function testOpERC20TotalSupplyEvalTwoOutputs() external {
        checkBadOutputs("_ _: erc20-total-supply(0xdeadbeef);", 1, 1, 2);
    }

    /// Test that a token without `decimals()` reverts with ReadFailure.
    function testOpERC20TotalSupplyDecimalsReadFailure() external {
        vm.mockCall(address(0xdeadbeef), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(uint256(1000)));
        // No mock for decimals — token doesn't implement it.
        checkUnhappy(
            "_: erc20-total-supply(0xdeadbeef);",
            abi.encodeWithSelector(
                ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, address(0xdeadbeef), TOFUOutcome.ReadFailure
            )
        );
    }

    /// Test that non-address token input reverts.
    function testOpERC20TotalSupplyNotAnAddress(uint256 token) external {
        // Casting to `uint160` is intentional to detect non-address values.
        //forge-lint: disable-next-line(unsafe-typecast)
        vm.assume(token != uint256(uint160(token)));
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] = StackItem.wrap(bytes32(token));
        OperandV2 operand = LibOperand.build(1, 1, 0);
        vm.expectRevert(abi.encodeWithSelector(NotAnAddress.selector, token));
        this.externalRun(operand, inputs);
    }

    function externalRun(OperandV2 operand, StackItem[] memory inputs) external view {
        LibOpERC20TotalSupply.run(opTestDefaultInterpreterState(), operand, inputs.asBytes32Array().dataPointer());
    }

    /// Test that operand is disallowed.
    function testOpERC20TotalSupplyEvalOperandDisallowed() external {
        checkUnhappyParse("_: erc20-total-supply<0>(0xdeadbeef);", abi.encodeWithSelector(UnexpectedOperand.selector));
    }
}
