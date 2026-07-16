// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ISubParserV4} from "rain-interpreter-interface-0.1.0/src/interface/ISubParserV4.sol";
import {IERC165} from "@openzeppelin-contracts-5.6.1/utils/introspection/IERC165.sol";
import {OPCODE_CONSTANT} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterV4.sol";

/// @dev A sub parser that returns multiple constants per word resolution.
contract MultiConstantSubParser is ISubParserV4, IERC165 {
    bytes32 public constant VALUE_A = bytes32(uint256(0xAAAA));
    bytes32 public constant VALUE_B = bytes32(uint256(0xBBBB));

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(ISubParserV4).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function subParseLiteral2(bytes calldata) external pure override returns (bool, bytes32) {
        return (false, 0);
    }

    /// @notice Returns a constant opcode with two constants. The first constant
    /// is used as the operand target; the second is an extra accumulation.
    function subParseWord2(bytes calldata data) external pure override returns (bool, bytes memory, bytes32[] memory) {
        uint256 constantsHeight = uint256(uint16(bytes2(data[0:2])));

        bytes memory bytecode = new bytes(4);
        // Safe: opcode constants and IO byte are small known values that fit
        // in uint8/bytes1.
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[0] = bytes1(uint8(OPCODE_CONSTANT));
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[1] = bytes1(uint8(0x10));
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[2] = bytes1(uint8(constantsHeight >> 8));
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[3] = bytes1(uint8(constantsHeight));

        bytes32[] memory constants = new bytes32[](2);
        constants[0] = VALUE_A;
        constants[1] = VALUE_B;

        return (true, bytecode, constants);
    }
}
