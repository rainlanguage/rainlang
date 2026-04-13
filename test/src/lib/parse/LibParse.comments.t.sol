// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OperandTest} from "test/abstract/OperandTest.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";

import {LibParse} from "../../../../src/lib/parse/LibParse.sol";
import {LibBytecode} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";

import {UnclosedComment, UnexpectedComment, UnexpectedLHSChar} from "../../../../src/error/ErrParse.sol";
import {ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {LibParseError, MAGIC_NUMBER_RAIN_PARSE_ERROR_V1} from "../../../../src/lib/parse/LibParseError.sol";

/// @title LibParseCommentsTest
/// @notice Test that the parser correctly parses comments.
contract LibParseCommentsTest is OperandTest {
    using LibParse for ParseState;

    /// A single comment with no expected bytecode.
    function testParseCommentNoWords() external view {
        string memory s = "/* empty output */:;";
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(s).parse();
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(constants.length, 0);

        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 0 op
            hex"00"
            // 0 stack allocation
            hex"00"
            // 0 inputs
            hex"00"
            // 0 outputs
            hex"00"
        );
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 0);
        (uint256 sourceInputs, uint256 sourceOutputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(sourceInputs, 0);
        assertEq(sourceOutputs, 0);
    }

    /// A single comment with a single word in the bytecode.
    function testParseCommentSingleWord() external view {
        string memory s = "/* one word */\n_:a();";
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(s).parse();
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(constants.length, 0);

        // a
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 op
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 output
            hex"01"
            // a
            hex"02100000"
        );
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 1);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (uint256 sourceInputs, uint256 sourceOutputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(sourceInputs, 0);
        assertEq(sourceOutputs, 1);
    }

    /// Comments can be on the same line as source if there is some whitespace.
    function testParseCommentSingleWordSameLine() external view {
        string memory s = "/* same line comment */ _:a();";
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(s).parse();
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(constants.length, 0);

        // a
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 op
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 output
            hex"01"
            // a
            hex"02100000"
        );
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 1);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (uint256 sourceInputs, uint256 sourceOutputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(sourceInputs, 0);
        assertEq(sourceOutputs, 1);
    }

    /// Comments can appear between sources.
    function testParseCommentBetweenSources() external view {
        string memory s = "_:a(); /* interstitial comment */ _:b();";
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(s).parse();
        assertEq(LibBytecode.sourceCount(bytecode), 2);
        assertEq(constants.length, 0);

        assertEq(
            bytecode,
            // 2 sources
            hex"02"
            // 0 offset
            hex"0000"
            // 8 offset
            hex"0008"
            // 1 op
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 output
            hex"01"
            // a
            hex"02100000"
            // 1 op
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 output
            hex"01"
            // b
            hex"03100000"
        );

        // a
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 1);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (uint256 sourceInputs, uint256 sourceOutputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(sourceInputs, 0);
        assertEq(sourceOutputs, 1);

        // b
        sourceIndex = 1;
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 8);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 1);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (sourceInputs, sourceOutputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(sourceInputs, 0);
        assertEq(sourceOutputs, 1);
    }

    /// Comments can appear after sources.
    function testParseCommentAfterSources() external view {
        string memory s = "_:a(); _:b(); /* trailing comment */";
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(s).parse();
        assertEq(LibBytecode.sourceCount(bytecode), 2);
        assertEq(constants.length, 0);

        assertEq(
            bytecode,
            // 2 sources
            hex"02"
            // 0 offset
            hex"0000"
            // 8 offset
            hex"0008"
            // 1 op
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 output
            hex"01"
            // a
            hex"02100000"
            // 1 op
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 output
            hex"01"
            // b
            hex"03100000"
        );

        // a
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 1);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (uint256 sourceInputs, uint256 sourceOutputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(sourceInputs, 0);
        assertEq(sourceOutputs, 1);

        // b
        sourceIndex = 1;
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 8);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 1);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (sourceInputs, sourceOutputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(sourceInputs, 0);
        assertEq(sourceOutputs, 1);
    }

    /// Multiple comments can appear in a row.
    function testParseCommentMultiple() external view {
        string memory s = "/* comment 1 */ /* comment 2 */ _:a(); /* comment 3 */ _:b(); /* comment 4 */";
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(s).parse();
        assertEq(LibBytecode.sourceCount(bytecode), 2);
        assertEq(constants.length, 0);

        assertEq(
            bytecode,
            // 2 sources
            hex"02"
            // 0 offset
            hex"0000"
            // 4 offset
            hex"0008"
            // 1 op
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 output
            hex"01"
            // a
            hex"02100000"
            // 1 op
            hex"01"
            // 1 stack allocation
            hex"01"
            // 0 inputs
            hex"00"
            // 1 output
            hex"01"
            // b
            hex"03100000"
        );

        // a
        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 1);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (uint256 sourceInputs, uint256 sourceOutputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(sourceInputs, 0);
        assertEq(sourceOutputs, 1);

        // b
        sourceIndex = 1;
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 8);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 1);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (sourceInputs, sourceOutputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(sourceInputs, 0);
        assertEq(sourceOutputs, 1);
    }

    /// Comments can have many astericks within them without breaking out of the
    /// comment. Tests extra leading astericks.
    function testParseCommentManyAstericks() external view {
        string memory s = "/** _ */ _:a();";
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(s).parse();

        assertEq(LibBytecode.sourceCount(bytecode), 1);
        // a
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 op
            hex"01"
            // 1 stack allocation
            hex"01"
            // 1 input
            hex"00"
            // 1 output
            hex"01"
            // a
            hex"02100000"
        );
        assertEq(constants.length, 0);

        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 1);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (uint256 sourceInputs, uint256 sourceOutputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(sourceInputs, 0);
        assertEq(sourceOutputs, 1);
    }

    /// Comments can have many astericks within them without breaking out of the
    /// comment. Tests extra trailing astericks.
    function testParseCommentManyAstericksTrailing() external view {
        string memory s = "/* _ **/ _:a();";
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(s).parse();

        assertEq(LibBytecode.sourceCount(bytecode), 1);
        // a
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 op
            hex"01"
            // 1 stack allocation
            hex"01"
            // 1 input
            hex"00"
            // 1 output
            hex"01"
            // a
            hex"02100000"
        );
        assertEq(constants.length, 0);

        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 1);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (uint256 sourceInputs, uint256 sourceOutputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(sourceInputs, 0);
        assertEq(sourceOutputs, 1);
    }

    /// Comments can be very long and span multiple lines.
    function testParseCommentLong() external view {
        string memory s =
            "/* this is a very \nlong comment that \nspans multiple lines **** and has many \nwords */ _:a();";
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState(s).parse();

        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(constants.length, 0);

        // a
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 op
            hex"01"
            // 1 stack allocation
            hex"01"
            // 1 input
            hex"00"
            // 1 output
            hex"01"
            // a
            hex"02100000"
        );

        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 1);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (uint256 sourceInputs, uint256 sourceOutputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(sourceInputs, 0);
        assertEq(sourceOutputs, 1);
    }

    /// Comments cause yang so cannot be without trailing whitespace.
    function testParseCommentNoTrailingWhitespace() external {
        string memory s = "/* comment */_:a();";
        vm.expectRevert(
            abi.encodeWithSelector(UnexpectedLHSChar.selector, uint256(MAGIC_NUMBER_RAIN_PARSE_ERROR_V1) | 13)
        );
        this.parse(bytes(s));
    }

    /// Comments cannot be in an ignored LHS item.
    function testParseCommentInIgnoredLHS() external {
        string memory s = "_/* comment */:a();";
        vm.expectRevert(
            abi.encodeWithSelector(UnexpectedComment.selector, uint256(MAGIC_NUMBER_RAIN_PARSE_ERROR_V1) | 1)
        );
        this.parse(bytes(s));
    }

    /// Comments cannot be in a named LHS item.
    function testParseCommentInNamedLHS() external {
        string memory s = "_a/* comment */:a();";
        vm.expectRevert(
            abi.encodeWithSelector(UnexpectedComment.selector, uint256(MAGIC_NUMBER_RAIN_PARSE_ERROR_V1) | 2)
        );
        this.parse(bytes(s));
    }

    /// Comments cannot be in the whitespace between LHS items.
    function testParseCommentInLHSWhitespace() external {
        string memory s = "_ /* comment */ _:a();";
        vm.expectRevert(
            abi.encodeWithSelector(UnexpectedComment.selector, uint256(MAGIC_NUMBER_RAIN_PARSE_ERROR_V1) | 2)
        );
        this.parse(bytes(s));
    }

    /// Comments cannot be in the RHS. Tests the start of the RHS.
    function testParseCommentInRHS() external {
        string memory s = "_:/* comment */a();";
        vm.expectRevert(
            abi.encodeWithSelector(UnexpectedComment.selector, uint256(MAGIC_NUMBER_RAIN_PARSE_ERROR_V1) | 2)
        );
        this.parse(bytes(s));
    }

    /// Comments cannot be in the RHS. Tests the middle of the RHS.
    function testParseCommentInRHS2() external {
        string memory s = "_:a()/* comment */ b();";
        vm.expectRevert(
            abi.encodeWithSelector(UnexpectedComment.selector, uint256(MAGIC_NUMBER_RAIN_PARSE_ERROR_V1) | 5)
        );
        this.parse(bytes(s));
    }

    /// Comments cannot be in the RHS. Tests the end of the RHS.
    function testParseCommentInRHS3() external {
        string memory s = "_:a()/* comment */;";
        vm.expectRevert(
            abi.encodeWithSelector(UnexpectedComment.selector, uint256(MAGIC_NUMBER_RAIN_PARSE_ERROR_V1) | 5)
        );
        this.parse(bytes(s));
    }

    /// Unclosed comments don't escape the data bounds.
    function testParseCommentUnclosed() external {
        string memory s = "/* unclosed comment";
        vm.expectRevert(abi.encodeWithSelector(UnclosedComment.selector, LibParseError.tagErrorOffset(19)));
        this.parse(bytes(s));
    }

    /// A comment that starts the end sequence but doesn't finish it is unclosed
    /// so must revert and not escape the data bounds.
    function testParseCommentUnclosed2() external {
        string memory s = "/* unclosed comment *";
        vm.expectRevert(abi.encodeWithSelector(UnclosedComment.selector, LibParseError.tagErrorOffset(21)));
        this.parse(bytes(s));
    }
}
