// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IntOrAString, LibIntOrAString} from "rain-intorastring-0.1.4/src/lib/LibIntOrAString.sol";
import {StackItem} from "../../../src/interface/IInterpreterV4.sol";

library LibFuzzString {
    /// The first `length` bytes of `word`.
    function leading(bytes32 word, uint256 length) internal pure returns (bytes memory) {
        bytes memory s = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            s[i] = word[i];
        }
        return s;
    }

    function stackItem(bytes memory s) internal pure returns (StackItem) {
        return StackItem.wrap(bytes32(IntOrAString.unwrap(LibIntOrAString.fromStringV3(string(s)))));
    }
}
