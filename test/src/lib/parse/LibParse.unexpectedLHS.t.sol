// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ParseTest} from "test/abstract/ParseTest.sol";
import {
    CMASK_COMMENT_HEAD,
    CMASK_IDENTIFIER_TAIL,
    CMASK_LHS_RHS_DELIMITER,
    CMASK_LHS_STACK_DELIMITER,
    CMASK_LHS_STACK_HEAD
} from "rain.string/lib/parse/LibParseCMask.sol";
import {LibParse, UnexpectedLHSChar} from "../../../../src/lib/parse/LibParse.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";

/// @title LibParseUnexpectedLHSTest
/// @notice The parser should revert if it encounters an unexpected character on the LHS.
contract LibParseUnexpectedLHSTest is ParseTest {
    using LibParse for ParseState;

    /// Check the parser reverts if it encounters an unexpected EOL on the LHS.
    function testParseUnexpectedLHSEOL() external {
        vm.expectRevert(abi.encodeWithSelector(UnexpectedLHSChar.selector, LibParseError.tagErrorOffset(0)));
        this.parseExternal(",");

        vm.expectRevert(abi.encodeWithSelector(UnexpectedLHSChar.selector, LibParseError.tagErrorOffset(1)));
        this.parseExternal(" ,");

        vm.expectRevert(abi.encodeWithSelector(UnexpectedLHSChar.selector, LibParseError.tagErrorOffset(1)));
        this.parseExternal("_,");
    }

    /// Check the parser reverts if it encounters an unexpected EOF on the LHS.
    function testParseUnexpectedLHSEOF() external {
        vm.expectRevert(abi.encodeWithSelector(UnexpectedLHSChar.selector, LibParseError.tagErrorOffset(0)));
        this.parseExternal(";");

        vm.expectRevert(abi.encodeWithSelector(UnexpectedLHSChar.selector, LibParseError.tagErrorOffset(1)));
        this.parseExternal(" ;");

        vm.expectRevert(abi.encodeWithSelector(UnexpectedLHSChar.selector, LibParseError.tagErrorOffset(1)));
        this.parseExternal("_;");
    }

    /// Check the parser reverts if it encounters underscores in the tail of an
    /// LHS item.
    function testParseUnexpectedLHSUnderscoreTail() external {
        vm.expectRevert(abi.encodeWithSelector(UnexpectedLHSChar.selector, LibParseError.tagErrorOffset(1)));
        this.parseExternal("a_:;");

        vm.expectRevert(abi.encodeWithSelector(UnexpectedLHSChar.selector, LibParseError.tagErrorOffset(3)));
        this.parseExternal("a __:;");

        vm.expectRevert(abi.encodeWithSelector(UnexpectedLHSChar.selector, LibParseError.tagErrorOffset(2)));
        this.parseExternal("_a_:;");
    }

    /// Check the parser reverts if it encounters an unexpected character as the
    /// head of something on the LHS.
    function testParseUnexpectedLHSSingleChar(uint8 a) external {
        vm.assume(
            //forge-lint: disable-next-line(incorrect-shift)
            1 << uint256(a)
                    & (CMASK_LHS_RHS_DELIMITER | CMASK_LHS_STACK_HEAD | CMASK_LHS_STACK_DELIMITER | CMASK_COMMENT_HEAD)
                == 0
        );

        vm.expectRevert(abi.encodeWithSelector(UnexpectedLHSChar.selector, LibParseError.tagErrorOffset(0)));
        this.parseExternal(string(bytes.concat(bytes1(a), ":;")));
    }

    /// Check the parser reverts if it encounters an unexpected character as the
    /// first character of an anonymous identifier on the LHS.
    function testParseUnexpectedLHSBadIgnoredTail(uint8 a) external {
        vm.assume(
            //forge-lint: disable-next-line(incorrect-shift)
            1 << uint256(a)
                    & (CMASK_LHS_RHS_DELIMITER | CMASK_IDENTIFIER_TAIL | CMASK_LHS_STACK_DELIMITER | CMASK_COMMENT_HEAD)
                == 0
        );

        vm.expectRevert(abi.encodeWithSelector(UnexpectedLHSChar.selector, LibParseError.tagErrorOffset(1)));
        this.parseExternal(string(bytes.concat("_", bytes1(a), ":;")));
    }

    /// Check the parser reverts if it encounters an unexpected character as the
    /// tail of a named identifier on the LHS.
    function testParseUnexpectedLHSBadNamedTail(uint8 a, bytes memory b) external {
        // a-z
        a = uint8(bound(a, 0x61, 0x7A));

        bool hasInvalidChar = false;
        uint256 i = 0;
        for (; i < b.length; i++) {
            bytes1 c = b[i];
            vm.assume(
                //forge-lint: disable-next-line(incorrect-shift)
                1 << uint256(uint8(c)) & (CMASK_LHS_STACK_DELIMITER | CMASK_LHS_RHS_DELIMITER | CMASK_COMMENT_HEAD) == 0
            );
            //forge-lint: disable-next-line(incorrect-shift)
            hasInvalidChar = 1 << uint256(uint8(c)) & CMASK_IDENTIFIER_TAIL == 0;
            if (hasInvalidChar) break;
        }
        vm.assume(hasInvalidChar);

        bytes memory identifier = bytes.concat(bytes1(a), b);
        vm.assume(identifier.length > 0);
        vm.assume(identifier.length < 32);

        vm.expectRevert(abi.encodeWithSelector(UnexpectedLHSChar.selector, LibParseError.tagErrorOffset(i + 1)));
        (bytes memory bytecode, bytes32[] memory constants) = this.parseExternal(string(bytes.concat(identifier, ":;")));
        (bytecode, constants);
    }
}
