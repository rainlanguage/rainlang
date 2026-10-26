// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {BytecodeTest} from "test/abstract/BytecodeTest.sol";
import {LibBytecode, SourceIndexOutOfBounds} from "../../../../src/lib/bytecode/LibBytecode.sol";
import {LibBytecodeSlow} from "test/src/lib/bytecode/LibBytecodeSlow.sol";

contract LibBytecodeSourceInputsOutputsTest is BytecodeTest {
    /// Concrete value-pinning tests for sourceInputsOutputsLength.
    function testSourceInputsOutputsConcrete() external pure {
        // 1 source, 0 ops, alloc=0, inputs=0, outputs=0.
        (uint256 i0, uint256 o0) = LibBytecode.sourceInputsOutputsLength(hex"01000000000000", 0);
        assertEq(i0, 0);
        assertEq(o0, 0);
        // 1 source, 0 ops, alloc=5, inputs=2, outputs=3.
        (uint256 i1, uint256 o1) = LibBytecode.sourceInputsOutputsLength(hex"01000000050203", 0);
        assertEq(i1, 2);
        assertEq(o1, 3);
        // 1 source, 0 ops, alloc=0xFF, inputs=0xFF, outputs=0xFF.
        (uint256 i2, uint256 o2) = LibBytecode.sourceInputsOutputsLength(hex"01000000ffffff", 0);
        assertEq(i2, 0xFF);
        assertEq(o2, 0xFF);
        // 2 sources: source 0 inputs=1,outputs=2; source 1 inputs=3,outputs=4.
        (uint256 i3, uint256 o3) = LibBytecode.sourceInputsOutputsLength(hex"02000000040003010200070304", 0);
        assertEq(i3, 1);
        assertEq(o3, 2);
        (uint256 i4, uint256 o4) = LibBytecode.sourceInputsOutputsLength(hex"02000000040003010200070304", 1);
        assertEq(i4, 3);
        assertEq(o4, 4);
    }

    function sourceInputsOutputsExternal(bytes memory bytecode, uint256 sourceIndex)
        external
        pure
        returns (uint256 inputs, uint256 outputs)
    {
        return LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
    }

    /// Getting source inputs and outputs for an index beyond the sources should
    /// fail.
    function testSourceInputsOutputsIndexOutOfBounds(
        bytes memory bytecode,
        uint256 sourceCount,
        uint256 sourceIndex,
        bytes32 seed
    ) external {
        conformBytecode(bytecode, sourceCount, seed);
        sourceCount = LibBytecode.sourceCount(bytecode);
        sourceIndex = bound(sourceIndex, sourceCount, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(SourceIndexOutOfBounds.selector, sourceIndex, bytecode));
        this.sourceInputsOutputsExternal(bytecode, sourceIndex);
    }

    /// Test against a reference implementation.
    function testSourceInputsOutputsAgainstSlow(
        bytes memory bytecode,
        uint256 sourceCount,
        uint256 sourceIndex,
        bytes32 seed
    ) external pure {
        conformBytecode(bytecode, sourceCount, seed);
        sourceCount = LibBytecode.sourceCount(bytecode);
        vm.assume(sourceCount > 0);
        sourceIndex = bound(sourceIndex, 0, sourceCount - 1);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        (uint256 slowInputs, uint256 slowOutputs) = LibBytecodeSlow.sourceInputsOutputsLengthSlow(bytecode, sourceIndex);
        assertEq(inputs, slowInputs);
        assertEq(outputs, slowOutputs);
    }
}
