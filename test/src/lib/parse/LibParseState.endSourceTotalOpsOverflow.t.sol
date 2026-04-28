// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ParseTest} from "test/abstract/ParseTest.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {SourceTotalOpsOverflow} from "../../../../src/error/ErrParse.sol";

/// @title LibParseStateEndSourceTotalOpsOverflowTest
/// @notice Tests that endSource reverts when the total ops count across all
/// top-level items in a single source exceeds the 255 limit of the prefix byte.
contract LibParseStateEndSourceTotalOpsOverflowTest is ParseTest {
    using LibParse for ParseState;

    /// Builds a balanced binary tree expression with 2^(depth+1)-1 total ops.
    /// Uses the zero-input word `a()` at the leaves.
    function buildTree(uint256 depth) internal pure returns (bytes memory) {
        bytes memory s = "a()";
        for (uint256 i = 0; i < depth; i++) {
            s = bytes.concat("a(", s, " ", s, ")");
        }
        return s;
    }

    /// 254 total ops across two items must NOT overflow.
    /// Two items: 127 ops + 127 ops = 254 total.
    function testTotalOps254NoOverflow() external view {
        bytes memory tree127 = buildTree(6);
        string memory s = string(bytes.concat("_: ", tree127, ",\n_: ", tree127, ";"));
        LibMetaFixture.newState(s).parse();
    }

    /// 256 total ops across two items MUST overflow.
    /// Two items: 128 ops + 128 ops = 256 total.
    function testTotalOpsOverflow256() external {
        bytes memory tree128 = bytes.concat("a(", buildTree(6), ")");
        string memory s = string(bytes.concat("_: ", tree128, ",\n_: ", tree128, ";"));
        vm.expectRevert(abi.encodeWithSelector(SourceTotalOpsOverflow.selector));
        this.parseExternal(s);
    }

    /// 510 total ops across two items MUST overflow.
    /// Two items: 255 ops + 255 ops = 510 total.
    function testTotalOpsOverflow510() external {
        bytes memory tree = buildTree(7);
        string memory s = string(bytes.concat("_: ", tree, ",\n_: ", tree, ";"));
        vm.expectRevert(abi.encodeWithSelector(SourceTotalOpsOverflow.selector));
        this.parseExternal(s);
    }
}
