// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibSubParse} from "../../../../src/lib/parse/LibSubParse.sol";
import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {LibBytecode, Pointer} from "rain-interpreter-interface-0.1.0/src/lib/bytecode/LibBytecode.sol";
import {ISubParserV4} from "rain-interpreter-interface-0.1.0/src/interface/ISubParserV4.sol";
import {IERC165} from "@openzeppelin-contracts-5.6.1/utils/introspection/IERC165.sol";
import {
    OPCODE_UNKNOWN,
    OPCODE_CONSTANT,
    OPCODE_CONTEXT
} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterV4.sol";
import {Strings} from "@openzeppelin-contracts-5.6.1/utils/Strings.sol";
import {UnknownWord} from "../../../../src/error/ErrParse.sol";

/// @dev A sub parser that resolves any word by returning a context opcode with
/// no constants. Used to verify that subParseWords iterates multiple sources.
contract ContextReturningSubParser is ISubParserV4, IERC165 {
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(ISubParserV4).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function subParseLiteral2(bytes calldata) external pure override returns (bool, bytes32) {
        return (false, 0);
    }

    /// @notice Returns a context opcode (0,0) with no constants.
    function subParseWord2(bytes calldata) external pure override returns (bool, bytes memory, bytes32[] memory) {
        bytes memory bytecode = new bytes(4);
        // Safe: opcode constant and IO byte are small known values.
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[0] = bytes1(uint8(OPCODE_CONTEXT));
        //forge-lint: disable-next-line(unsafe-typecast)
        bytecode[1] = bytes1(uint8(0x10)); // 0 inputs, 1 output
        bytecode[2] = bytes1(0); // row 0
        bytecode[3] = bytes1(0); // column 0
        return (true, bytecode, new bytes32[](0));
    }
}
