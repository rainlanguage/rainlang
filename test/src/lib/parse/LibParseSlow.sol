// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

library LibParseSlow {
    function parseWordSlow(bytes memory data, uint256 mask) internal pure returns (uint256) {
        if (data.length > 1) {
            for (uint256 i = 1; i < data.length; i++) {
                //forge-lint: disable-next-line(incorrect-shift)
                if ((1 << uint256(uint8(data[i]))) & mask == 0) {
                    return i;
                }
            }
        }
        return data.length;
    }
}
