// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OperandTest} from "test/abstract/OperandTest.sol";

import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {LibBytecode} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {MaxSources} from "../../../../src/error/ErrParse.sol";

/// @title LibParseEmptyTest
/// @notice Tests parsing empty sources and constants. All we want to check is that the
/// parser doesn't revert and the correct number of sources and constants are
/// returned.
contract LibParseEmptyTest is OperandTest {
    using LibParse for ParseState;

    /// Check truly empty input bytes. Should not revert and return length 0
    /// sources and constants.
    function testParseEmpty00() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("").parse();

        assertEq(LibBytecode.sourceCount(bytecode), 0);
        assertEq(
            bytecode,
            // 0 sources
            hex"00"
        );

        assertEq(constants.length, 0);
    }

    /// Check a single empty expression. Should not revert and return length 1
    /// sources and constants.
    function testParseEmpty01() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(":;").parse();
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 0 ops
            hex"00"
            // 0 stack allocation
            hex"00"
            // 0 inputs
            hex"00"
            // 0 outputs
            hex"00"
        );

        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 0);
        (uint256 sourceInputs, uint256 sourceOutputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(sourceInputs, 0);
        assertEq(sourceOutputs, 0);

        assertEq(constants.length, 0);
    }

    /// Check two empty expressions. Should not revert and return length 2
    /// sources and constants.
    function testParseEmpty02() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(":;:;").parse();
        assertEq(LibBytecode.sourceCount(bytecode), 2);
        assertEq(
            bytecode,
            // 2 sources
            hex"02"
            // 0 offset
            hex"0000"
            // 4 offset
            hex"0004"
            // 0. 0 ops
            hex"00"
            // 0. 0 stack allocation
            hex"00"
            // 0. 0 inputs
            hex"00"
            // 0. 0 outputs
            hex"00"
            // 1. 0 ops
            hex"00"
            // 1. 0 stack allocation
            hex"00"
            // 1. 0 inputs
            hex"00"
            // 1. 0 outputs
            hex"00"
        );

        for (uint256 i = 0; i < 2; i++) {
            assertEq(LibBytecode.sourceRelativeOffset(bytecode, i), i * 4);
            assertEq(LibBytecode.sourceOpsCount(bytecode, i), 0);
            assertEq(LibBytecode.sourceStackAllocation(bytecode, i), 0);
            (uint256 sourceInputs, uint256 sourceOutputs) = LibBytecode.sourceInputsOutputsLength(bytecode, i);
            assertEq(sourceInputs, 0);
            assertEq(sourceOutputs, 0);
        }

        assertEq(constants.length, 0);
    }

    /// Check three empty expressions. Should not revert and return length 3
    /// sources and constants.
    function testParseEmpty03() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(":;:;:;").parse();
        assertEq(LibBytecode.sourceCount(bytecode), 3);
        assertEq(
            bytecode,
            // 3 sources
            hex"03"
            // 0 offset
            hex"0000"
            // 4 offset
            hex"0004"
            // 8 offset
            hex"0008"
            // 0. 0 ops
            hex"00"
            // 0. 0 stack allocation
            hex"00"
            // 0. 0 inputs
            hex"00"
            // 0. 0 outputs
            hex"00"
            // 1. 0 ops
            hex"00"
            // 1. 0 stack allocation
            hex"00"
            // 1. 0 inputs
            hex"00"
            // 1. 0 outputs
            hex"00"
            // 2. 0 ops
            hex"00"
            // 2. 0 stack allocation
            hex"00"
            // 2. 0 inputs
            hex"00"
            // 2. 0 outputs
            hex"00"
        );

        for (uint256 i = 0; i < 3; i++) {
            assertEq(LibBytecode.sourceRelativeOffset(bytecode, i), i * 4);
            assertEq(LibBytecode.sourceOpsCount(bytecode, i), 0);
            assertEq(LibBytecode.sourceStackAllocation(bytecode, i), 0);
            (uint256 sourceInputs, uint256 sourceOutputs) = LibBytecode.sourceInputsOutputsLength(bytecode, i);
            assertEq(sourceInputs, 0);
            assertEq(sourceOutputs, 0);
        }

        assertEq(constants.length, 0);
    }

    /// Check four empty expressions. Should not revert and return length 4
    /// sources and constants.
    function testParseEmpty04() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(":;:;:;:;").parse();
        assertEq(LibBytecode.sourceCount(bytecode), 4);
        assertEq(
            bytecode,
            // 4 sources
            hex"04"
            // 0 offset
            hex"0000"
            // 4 offset
            hex"0004"
            // 8 offset
            hex"0008"
            // 12 offset
            hex"000c"
            // 0. 0 ops
            hex"00"
            // 0. 0 stack allocation
            hex"00"
            // 0. 0 inputs
            hex"00"
            // 0. 0 outputs
            hex"00"
            // 1. 0 ops
            hex"00"
            // 1. 0 stack allocation
            hex"00"
            // 1. 0 inputs
            hex"00"
            // 1. 0 outputs
            hex"00"
            // 2. 0 ops
            hex"00"
            // 2. 0 stack allocation
            hex"00"
            // 2. 0 inputs
            hex"00"
            // 2. 0 outputs
            hex"00"
            // 3. 0 ops
            hex"00"
            // 3. 0 stack allocation
            hex"00"
            // 3. 0 inputs
            hex"00"
            // 3. 0 outputs
            hex"00"
        );

        for (uint256 i = 0; i < 4; i++) {
            assertEq(LibBytecode.sourceRelativeOffset(bytecode, i), i * 4);
            assertEq(LibBytecode.sourceOpsCount(bytecode, i), 0);
            assertEq(LibBytecode.sourceStackAllocation(bytecode, i), 0);
            (uint256 sourceInputs, uint256 sourceOutputs) = LibBytecode.sourceInputsOutputsLength(bytecode, i);
            assertEq(sourceInputs, 0);
            assertEq(sourceOutputs, 0);
        }

        assertEq(constants.length, 0);
    }

    /// Check eight empty expressions. Should not revert and return length 8
    /// sources and constants.
    function testParseEmpty08() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(":;:;:;:;:;:;:;:;").parse();
        assertEq(LibBytecode.sourceCount(bytecode), 8);
        assertEq(
            bytecode,
            // 8 sources
            hex"08"
            // 0 offset
            hex"0000"
            // 4 offset
            hex"0004"
            // 8 offset
            hex"0008"
            // 12 offset
            hex"000c"
            // 16 offset
            hex"0010"
            // 20 offset
            hex"0014"
            // 24 offset
            hex"0018"
            // 28 offset
            hex"001c"
            // 0. 0 ops
            hex"00"
            // 0. 0 stack allocation
            hex"00"
            // 0. 0 inputs
            hex"00"
            // 0. 0 outputs
            hex"00"
            // 1. 0 ops
            hex"00"
            // 1. 0 stack allocation
            hex"00"
            // 1. 0 inputs
            hex"00"
            // 1. 0 outputs
            hex"00"
            // 2. 0 ops
            hex"00"
            // 2. 0 stack allocation
            hex"00"
            // 2. 0 inputs
            hex"00"
            // 2. 0 outputs
            hex"00"
            // 3. 0 ops
            hex"00"
            // 3. 0 stack allocation
            hex"00"
            // 3. 0 inputs
            hex"00"
            // 3. 0 outputs
            hex"00"
            // 4. 0 ops
            hex"00"
            // 4. 0 stack allocation
            hex"00"
            // 4. 0 inputs
            hex"00"
            // 4. 0 outputs
            hex"00"
            // 5. 0 ops
            hex"00"
            // 5. 0 stack allocation
            hex"00"
            // 5. 0 inputs
            hex"00"
            // 5. 0 outputs
            hex"00"
            // 6. 0 ops
            hex"00"
            // 6. 0 stack allocation
            hex"00"
            // 6. 0 inputs
            hex"00"
            // 6. 0 outputs
            hex"00"
            // 7. 0 ops
            hex"00"
            // 7. 0 stack allocation
            hex"00"
            // 7. 0 inputs
            hex"00"
            // 7. 0 outputs
            hex"00"
        );

        for (uint256 i = 0; i < 8; i++) {
            assertEq(LibBytecode.sourceRelativeOffset(bytecode, i), i * 4);
            assertEq(LibBytecode.sourceOpsCount(bytecode, i), 0);
            assertEq(LibBytecode.sourceStackAllocation(bytecode, i), 0);
            (uint256 sourceInputs, uint256 sourceOutputs) = LibBytecode.sourceInputsOutputsLength(bytecode, i);
            assertEq(sourceInputs, 0);
            assertEq(sourceOutputs, 0);
        }

        assertEq(constants.length, 0);
    }

    /// Check fifteen empty expressions. Should not revert and return length 15
    /// sources and constants.
    function testParseEmpty15() external view {
        (bytes memory bytecode, bytes32[] memory constants) =
            LibMetaFixture.newState(":;:;:;:;:;:;:;:;:;:;:;:;:;:;:;").parse();
        assertEq(LibBytecode.sourceCount(bytecode), 15);
        assertEq(
            bytecode,
            // 15 sources
            hex"0f"
            // 0 offset
            hex"0000"
            // 4 offset
            hex"0004"
            // 8 offset
            hex"0008"
            // 12 offset
            hex"000c"
            // 16 offset
            hex"0010"
            // 20 offset
            hex"0014"
            // 24 offset
            hex"0018"
            // 28 offset
            hex"001c"
            // 32 offset
            hex"0020"
            // 36 offset
            hex"0024"
            // 40 offset
            hex"0028"
            // 44 offset
            hex"002c"
            // 48 offset
            hex"0030"
            // 52 offset
            hex"0034"
            // 56 offset
            hex"0038"
            // 0. 0 ops
            hex"00"
            // 0. 0 stack allocation
            hex"00"
            // 0. 0 inputs
            hex"00"
            // 0. 0 outputs
            hex"00"
            // 1. 0 ops
            hex"00"
            // 1. 0 stack allocation
            hex"00"
            // 1. 0 inputs
            hex"00"
            // 1. 0 outputs
            hex"00"
            // 2. 0 ops
            hex"00"
            // 2. 0 stack allocation
            hex"00"
            // 2. 0 inputs
            hex"00"
            // 2. 0 outputs
            hex"00"
            // 3. 0 ops
            hex"00"
            // 3. 0 stack allocation
            hex"00"
            // 3. 0 inputs
            hex"00"
            // 3. 0 outputs
            hex"00"
            // 4. 0 ops
            hex"00"
            // 4. 0 stack allocation
            hex"00"
            // 4. 0 inputs
            hex"00"
            // 4. 0 outputs
            hex"00"
            // 5. 0 ops
            hex"00"
            // 5. 0 stack allocation
            hex"00"
            // 5. 0 inputs
            hex"00"
            // 5. 0 outputs
            hex"00"
            // 6. 0 ops
            hex"00"
            // 6. 0 stack allocation
            hex"00"
            // 6. 0 inputs
            hex"00"
            // 6. 0 outputs
            hex"00"
            // 7. 0 ops
            hex"00"
            // 7. 0 stack allocation
            hex"00"
            // 7. 0 inputs
            hex"00"
            // 7. 0 outputs
            hex"00"
            // 8. 0 ops
            hex"00"
            // 8. 0 stack allocation
            hex"00"
            // 8. 0 inputs
            hex"00"
            // 8. 0 outputs
            hex"00"
            // 9. 0 ops
            hex"00"
            // 9. 0 stack allocation
            hex"00"
            // 9. 0 inputs
            hex"00"
            // 9. 0 outputs
            hex"00"
            // 10. 0 ops
            hex"00"
            // 10. 0 stack allocation
            hex"00"
            // 10. 0 inputs
            hex"00"
            // 10. 0 outputs
            hex"00"
            // 11. 0 ops
            hex"00"
            // 11. 0 stack allocation
            hex"00"
            // 11. 0 inputs
            hex"00"
            // 11. 0 outputs
            hex"00"
            // 12. 0 ops
            hex"00"
            // 12. 0 stack allocation
            hex"00"
            // 12. 0 inputs
            hex"00"
            // 12. 0 outputs
            hex"00"
            // 13. 0 ops
            hex"00"
            // 13. 0 stack allocation
            hex"00"
            // 13. 0 inputs
            hex"00"
            // 13. 0 outputs
            hex"00"
            // 14. 0 ops
            hex"00"
            // 14. 0 stack allocation
            hex"00"
            // 14. 0 inputs
            hex"00"
            // 14. 0 outputs
            hex"00"
        );

        for (uint256 i = 0; i < 15; i++) {
            assertEq(LibBytecode.sourceRelativeOffset(bytecode, i), i * 4);
            assertEq(LibBytecode.sourceOpsCount(bytecode, i), 0);
            assertEq(LibBytecode.sourceStackAllocation(bytecode, i), 0);
            (uint256 sourceInputs, uint256 sourceOutputs) = LibBytecode.sourceInputsOutputsLength(bytecode, i);
            assertEq(sourceInputs, 0);
            assertEq(sourceOutputs, 0);
        }

        assertEq(constants.length, 0);
    }

    /// Check sixteen empty expressions. Should revert as one of the sources is
    /// actually reserved to track the length of the sources in the internal
    /// state of the parser.
    function testParseEmptyError16() external {
        vm.expectRevert(abi.encodeWithSelector(MaxSources.selector));
        this.parse(bytes(":;:;:;:;:;:;:;:;:;:;:;:;:;:;:;:;"));
    }
}
