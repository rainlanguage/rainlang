// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {RainlangReferenceExtern} from "../../../src/concrete/extern/RainlangReferenceExtern.sol";

contract RainlangReferenceExternDescribedByMetaV1 is Test {
    function testRainlangReferenceExternDescribedByMetaV1Happy() external {
        RainlangReferenceExtern extern = new RainlangReferenceExtern();
        bytes memory describedByMeta = vm.readFileBinary("meta/RainlangReferenceExtern.rain.meta");

        assertEq(keccak256(describedByMeta), extern.describedByMetaV1());
    }
}
