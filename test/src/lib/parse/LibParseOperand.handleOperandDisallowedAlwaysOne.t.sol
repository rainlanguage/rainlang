// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseOperand, OperandV2} from "../../../../src/lib/parse/LibParseOperand.sol";
import {UnexpectedOperand} from "../../../../src/error/ErrParse.sol";

contract LibParseOperandHandleOperandDisallowedAlwaysOneTest is Test {
    function handleOperandDisallowedAlwaysOneExternal(bytes32[] memory values) external pure returns (OperandV2) {
        return LibParseOperand.handleOperandDisallowedAlwaysOne(values);
    }

    /// Empty values must return operand 1.
    function testHandleOperandDisallowedAlwaysOneNoValues() external pure {
        assertEq(
            OperandV2.unwrap(LibParseOperand.handleOperandDisallowedAlwaysOne(new bytes32[](0))), bytes32(uint256(1))
        );
    }

    /// Any non-empty values must revert with UnexpectedOperand.
    function testHandleOperandDisallowedAlwaysOneAnyValues(bytes32[] memory values) external {
        vm.assume(values.length > 0);
        vm.expectRevert(abi.encodeWithSelector(UnexpectedOperand.selector));
        this.handleOperandDisallowedAlwaysOneExternal(values);
    }
}
