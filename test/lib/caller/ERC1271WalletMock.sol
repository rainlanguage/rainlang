// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IERC1271} from "@openzeppelin-contracts-5.7.0/interfaces/IERC1271.sol";
import {ECDSA} from "@openzeppelin-contracts-5.7.0/utils/cryptography/ECDSA.sol";

/// A contract account that validates ERC-1271 signatures against one EOA
/// owner key, as a smart wallet with a single signer does. Two wallets with
/// the same owner accept exactly the same `(hash, signature)` pairs, which is
/// the shape that puts `signer` in the `SignedContextV2` type. The owner can
/// revoke, after which nothing verifies.
contract ERC1271WalletMock is IERC1271 {
    address public immutable OWNER;
    bool public revoked;

    // A zero owner is a wallet that never validates, which is a legitimate
    // configuration for a mock.
    //forge-lint: disable-next-line(missing-zero-check)
    constructor(address owner) {
        OWNER = owner;
    }

    function revoke() external {
        revoked = true;
    }

    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4) {
        (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(hash, signature);
        if (!revoked && err == ECDSA.RecoverError.NoError && recovered == OWNER) {
            return IERC1271.isValidSignature.selector;
        }
        return bytes4(0);
    }
}
