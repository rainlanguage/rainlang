// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {EIP712} from "@openzeppelin-contracts-5.7.0/utils/cryptography/EIP712.sol";

/// @title EIP712DomainSeparatorSource
/// @notice An OpenZeppelin `EIP712` contract exposing its domain separator.
contract EIP712DomainSeparatorSource is EIP712 {
    constructor(string memory name, string memory version) EIP712(name, version) {}

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
}
