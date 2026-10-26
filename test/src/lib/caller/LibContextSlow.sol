// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {SignedContextV2} from "../../../../src/interface/IInterpreterCallerV5.sol";

library LibContextSlow {
    function buildStructureSlow(bytes32[][] memory baseContext, SignedContextV2[] memory signedContexts)
        internal
        view
        returns (bytes32[][] memory)
    {
        uint256 signedLen = signedContexts.length > 0 ? signedContexts.length + 2 : 0;
        bytes32[][] memory context = new bytes32[][](1 + baseContext.length + signedLen);
        context[0] = new bytes32[](2);
        context[0][0] = bytes32(uint256(uint160(address(msg.sender))));
        context[0][1] = bytes32(uint256(uint160(address(this))));

        uint256 offset = 1;
        uint256 i = 0;
        for (; i < baseContext.length; i++) {
            context[i + offset] = baseContext[i];
        }
        offset = offset + i;

        if (signedContexts.length > 0) {
            bytes32[] memory signers = new bytes32[](signedContexts.length);
            bytes32[] memory domainSeparators = new bytes32[](signedContexts.length);
            for (i = 0; i < signedContexts.length; i++) {
                signers[i] = bytes32(uint256(uint160(signedContexts[i].signer)));
                domainSeparators[i] = signedContexts[i].domainSeparator;
            }
            context[offset] = signers;
            context[offset + 1] = domainSeparators;
            offset = offset + 2;

            i = 0;
            for (; i < signedContexts.length; i++) {
                context[i + offset] = signedContexts[i].context;
            }
        }

        return context;
    }
}
