// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.19;

import {LibConvert} from "rain.lib.typecast/LibConvert.sol";

library LibIntegrityFnPointers {
    /// Generates fake IO function pointers as the index of each word, as a
    /// 2 byte value.
    function indexPointersForWords(bytes32[] memory words) internal pure returns (bytes memory) {
        uint256[] memory ioFnPointers = new uint256[](words.length);
        for (uint256 i = 0; i < words.length; i++) {
            ioFnPointers[i] = i;
        }
        return LibConvert.unsafeTo16BitBytes(ioFnPointers);
    }
}
