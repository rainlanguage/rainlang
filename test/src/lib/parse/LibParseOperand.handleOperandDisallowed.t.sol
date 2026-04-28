// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseOperand, OperandV2} from "../../../../src/lib/parse/LibParseOperand.sol";
import {UnexpectedOperand} from "../../../../src/error/ErrParse.sol";

contract LibParseOperandHandleOperandDisallowedTest is Test {
    function handleOperandDisallowedExternal(bytes32[] memory values) external pure returns (OperandV2) {
        return LibParseOperand.handleOperandDisallowed(values);
    }

    function testHandleOperandDisallowedNoValues() external pure {
        assertEq(OperandV2.unwrap(LibParseOperand.handleOperandDisallowed(new bytes32[](0))), 0);
    }

    function testHandleOperandDisallowedAnyValues(bytes32[] memory values) external {
        vm.assume(values.length > 0);
        vm.expectRevert(abi.encodeWithSelector(UnexpectedOperand.selector));
        this.handleOperandDisallowedExternal(values);
    }
}
