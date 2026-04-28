// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {LibInterpreterState, STACK_TRACER} from "../../../../src/lib/state/LibInterpreterState.sol";
import {Test} from "forge-std/Test.sol";

contract LibInterpreterStateStackTraceTest is Test {
    using LibUint256Array for uint256[];

    function testStackTraceCall(uint256 parentSourceIndex, uint256 sourceIndex, uint256[] memory inputs) external {
        parentSourceIndex = bound(parentSourceIndex, 0, 0xFFFF);
        sourceIndex = bound(sourceIndex, 0, 0xFFFF);
        uint256 lengthBefore = inputs.length;
        vm.expectCall(
            STACK_TRACER,
            // Safe typecast due to bounds above.
            //forge-lint: disable-next-line(unsafe-typecast)
            abi.encodePacked(bytes2(uint16(parentSourceIndex)), bytes2(uint16(sourceIndex)), inputs),
            1
        );
        LibInterpreterState.stackTrace(parentSourceIndex, sourceIndex, inputs.dataPointer(), inputs.endPointer());
        // Check we didn't corrupt the inputs length while mutating memory.
        assertEq(inputs.length, lengthBefore);
    }

    /// Upper bits beyond 16 in parentSourceIndex and sourceIndex must be
    /// masked off. The trace encoding is two uint16 values packed into 4
    /// bytes, so only the low 16 bits of each should appear.
    function testStackTraceMasksUpperBits(uint256 parentSourceIndex, uint256 sourceIndex, uint256[] memory inputs)
        external
    {
        vm.assume(parentSourceIndex > 0xFFFF || sourceIndex > 0xFFFF);
        uint256 lengthBefore = inputs.length;
        vm.expectCall(
            STACK_TRACER,
            //forge-lint: disable-next-line(unsafe-typecast)
            abi.encodePacked(bytes2(uint16(parentSourceIndex & 0xFFFF)), bytes2(uint16(sourceIndex & 0xFFFF)), inputs),
            1
        );
        LibInterpreterState.stackTrace(parentSourceIndex, sourceIndex, inputs.dataPointer(), inputs.endPointer());
        assertEq(inputs.length, lengthBefore);
    }
}
