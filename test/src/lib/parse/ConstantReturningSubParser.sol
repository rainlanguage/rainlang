// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {ISubParserV4} from "rain-interpreter-interface-0.1.0/src/interface/ISubParserV4.sol";
import {IERC165} from "@openzeppelin-contracts-5.6.1/utils/introspection/IERC165.sol";
import {OPCODE_CONSTANT} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterV4.sol";
import {LibBytecode, Pointer} from "rain-interpreter-interface-0.1.0/src/lib/bytecode/LibBytecode.sol";
import {Strings} from "@openzeppelin-contracts-5.6.1/utils/Strings.sol";

/// @dev A sub parser that resolves any word by returning a constant opcode
/// with a known constant value. Each call returns exactly one constant.
contract ConstantReturningSubParser is ISubParserV4, IERC165 {
    bytes32 public constant RETURN_VALUE = bytes32(uint256(0xDEADBEEF));

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(ISubParserV4).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function subParseLiteral2(bytes calldata) external pure override returns (bool, bytes32) {
        return (false, 0);
    }

    /// @notice Returns a constant opcode pointing at the current constants
    /// height from the header, with a single constant value.
    function subParseWord2(bytes calldata data) external pure override returns (bool, bytes memory, bytes32[] memory) {
        // Extract constantsHeight from header (first 2 bytes).
        uint256 constantsHeight = uint256(uint16(bytes2(data[0:2])));

        // Build 4-byte constant opcode: [OPCODE_CONSTANT][IO=0x10][operand=constantsHeight]
        bytes memory bytecode = new bytes(4);
        // Safe: opcode constants and IO byte are small known values that fit
        // in uint8/bytes1.
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[0] = bytes1(uint8(OPCODE_CONSTANT));
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[1] = bytes1(uint8(0x10)); // 0 inputs, 1 output
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[2] = bytes1(uint8(constantsHeight >> 8));
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[3] = bytes1(uint8(constantsHeight));

        bytes32[] memory constants = new bytes32[](1);
        constants[0] = RETURN_VALUE;

        return (true, bytecode, constants);
    }
}
