// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseState, ParseState, EMPTY_ACTIVE_SOURCE} from "../../../../src/lib/parse/LibParseState.sol";
import {LibBytecode} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";
import {OperandV2} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

contract LibParseStateBuildBytecodeTest is Test {
    using LibParseState for ParseState;
    using LibBytecode for bytes;

    /// A single source with one op must produce bytecode with sourceCount 1
    /// and opsCount 1.
    function testBuildBytecodeSingleSource() external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");
        state.pushOpToSource(0x42, OperandV2.wrap(bytes32(uint256(0x1234))));
        state.endSource();

        bytes memory bytecode = state.buildBytecode();

        assertEq(bytecode.sourceCount(), 1);
        assertEq(bytecode.sourceOpsCount(0), 1);
    }

    /// Two sources must both appear in the bytecode with correct ops counts.
    function testBuildBytecodeTwoSources() external pure {
        ParseState memory state = LibParseState.newState("", "", "", "");

        state.pushOpToSource(0, OperandV2.wrap(bytes32(0)));
        state.pushOpToSource(1, OperandV2.wrap(bytes32(0)));
        state.endSource();

        state.pushOpToSource(2, OperandV2.wrap(bytes32(0)));
        state.pushOpToSource(3, OperandV2.wrap(bytes32(0)));
        state.pushOpToSource(4, OperandV2.wrap(bytes32(0)));
        state.endSource();

        bytes memory bytecode = state.buildBytecode();

        assertEq(bytecode.sourceCount(), 2);
        assertEq(bytecode.sourceOpsCount(0), 2);
        assertEq(bytecode.sourceOpsCount(1), 3);
    }

    /// Fuzz source count and ops per source. Each source must report the
    /// correct ops count in the built bytecode.
    function testBuildBytecodeFuzz(uint256 sourceCountSeed, uint256 opsPerSourceSeed) external pure {
        uint256 nSources = bound(sourceCountSeed, 1, 15);
        ParseState memory state = LibParseState.newState("", "", "", "");

        uint256[] memory expectedOps = new uint256[](nSources);
        for (uint256 s = 0; s < nSources; s++) {
            uint256 nOps = bound(uint256(keccak256(abi.encode(opsPerSourceSeed, s))), 1, 20);
            expectedOps[s] = nOps;
            for (uint256 j = 0; j < nOps; j++) {
                // Safe: j % 256 fits in uint8 by definition.
                //forge-lint: disable-next-line(unsafe-typecast)
                state.pushOpToSource(uint8(j % 256), OperandV2.wrap(bytes32(uint256(j))));
            }
            state.endSource();
        }

        bytes memory bytecode = state.buildBytecode();

        assertEq(bytecode.sourceCount(), nSources);
        for (uint256 s = 0; s < nSources; s++) {
            assertEq(bytecode.sourceOpsCount(s), expectedOps[s]);
        }
    }
}
