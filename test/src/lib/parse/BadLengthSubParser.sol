// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OpTest} from "test/abstract/OpTest.sol";
import {ISubParserV4} from "rain-interpreter-interface-0.1.0/src/interface/ISubParserV4.sol";
import {IERC165} from "@openzeppelin-contracts-5.6.1/utils/introspection/IERC165.sol";
import {BadSubParserResult} from "../../../../src/error/ErrParse.sol";
import {Strings} from "@openzeppelin-contracts-5.6.1/utils/Strings.sol";

/// A bad sub parser that claims to know every word but returns bytecode of
/// the wrong length.
contract BadLengthSubParser is ISubParserV4, IERC165 {
    bytes public badBytecode;

    constructor(bytes memory badBytecode_) {
        badBytecode = badBytecode_;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(ISubParserV4).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function subParseLiteral2(bytes calldata) external pure override returns (bool, bytes32) {
        return (false, 0);
    }

    function subParseWord2(bytes calldata) external view override returns (bool, bytes memory, bytes32[] memory) {
        return (true, badBytecode, new bytes32[](0));
    }
}
