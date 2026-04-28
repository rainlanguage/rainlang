// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ParseTest} from "test/abstract/ParseTest.sol";

import {AuthoringMetaV2} from "rain.interpreter.interface/interface/IParserV2.sol";
import {LibParse, DuplicateLHSItem, WordSize} from "../../../../src/lib/parse/LibParse.sol";
import {LibBytecode} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";
import {LibMetaFixture} from "test/lib/parse/LibMetaFixture.sol";
import {LibParseState, ParseState} from "../../../../src/lib/parse/LibParseState.sol";
import {OperandV2, LibParseOperand} from "../../../../src/lib/parse/LibParseOperand.sol";
import {LibConvert} from "rain.lib.typecast/LibConvert.sol";
import {LibAllStandardOps} from "../../../../src/lib/op/LibAllStandardOps.sol";
import {LibParseError} from "../../../../src/lib/parse/LibParseError.sol";
import {LibGenParseMeta} from "rain.interpreter.interface/lib/codegen/LibGenParseMeta.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";

/// @title LibParseNamedLHSTest
/// @notice Tests for parsing named LHS items.
contract LibParseNamedLHSTest is ParseTest {
    using LibParse for ParseState;

    /// A few simple examples that should create some empty sources.
    function testParseNamedLHSEmptySourceExamples() external view {
        string[3] memory examples0 = ["a _:;", "a b:;", "foo bar:;"];
        for (uint256 i = 0; i < examples0.length; i++) {
            (bytes memory bytecode0, bytes32[] memory constants0) = LibMetaFixture.newState(examples0[i]).parse();
            assertEq(LibBytecode.sourceCount(bytecode0), 1);
            uint256 sourceIndex0 = 0;
            assertEq(LibBytecode.sourceRelativeOffset(bytecode0, sourceIndex0), 0);
            assertEq(LibBytecode.sourceOpsCount(bytecode0, sourceIndex0), 0);
            assertEq(LibBytecode.sourceStackAllocation(bytecode0, sourceIndex0), 2);
            (uint256 inputs0, uint256 outputs0) = LibBytecode.sourceInputsOutputsLength(bytecode0, sourceIndex0);
            assertEq(inputs0, 2);
            assertEq(outputs0, 2);
            assertEq(constants0.length, 0);
        }
    }

    /// Two sources with one named input each.
    function testParseNamedLHSTwoInputs() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibMetaFixture.newState("a:;b:;").parse();
        assertEq(
            bytecode,
            // 2 sources.
            hex"02"
            // offset 0
            hex"0000"
            // offset 4
            hex"0004"
            // 0 ops
            hex"00"
            // 1 stack allocation
            hex"01"
            // 1 input
            hex"01"
            // 1 output
            hex"01"
            // 0 ops
            hex"00"
            // 1 stack allocation
            hex"01"
            // 1 input
            hex"01"
            // 1 output
            hex"01"
        );

        assertEq(LibBytecode.sourceCount(bytecode), 2);

        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 1);
        assertEq(outputs, 1);

        sourceIndex = 1;
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 4);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 1);
        (inputs, outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 1);
        assertEq(outputs, 1);

        assertEq(constants.length, 0);
    }

    /// Exceeding the maximum length of a word should revert. Testing a 32 char
    /// is right at the limit.
    function testParseNamedError32() external {
        // Only the first 32 chars are visible in the error.
        vm.expectRevert(abi.encodeWithSelector(WordSize.selector, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"));
        // 32 chars is too long.
        this.parseExternal("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:;");
    }

    /// Exceeding the maximum length of a word should revert. Testing a 33 char
    /// word shows the difference between the actual source and the error.
    /// (The latter is truncated).
    function testParseNamedError33() external {
        // Only the first 32 chars are visible in the error.
        vm.expectRevert(abi.encodeWithSelector(WordSize.selector, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"));
        // 33 chars is too long.
        this.parseExternal("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:;");
    }

    /// Stack needs to index items by name correctly across lines.
    function testParseNamedLHSStackIndex() external view {
        AuthoringMetaV2[] memory meta = new AuthoringMetaV2[](3);
        meta[0] = AuthoringMetaV2("stack", "stack");
        meta[1] = AuthoringMetaV2("constant", "constant");
        meta[2] = AuthoringMetaV2("c", "c");
        bytes memory parseMeta = LibGenParseMeta.buildParseMetaV2(meta, 1);

        function(bytes32[] memory) internal pure returns (OperandV2)[] memory operandHandlers =
            new function(bytes32[] memory) internal pure returns (OperandV2)[](3);
        operandHandlers[0] = LibParseOperand.handleOperandDisallowed;
        operandHandlers[1] = LibParseOperand.handleOperandDisallowed;
        operandHandlers[2] = LibParseOperand.handleOperandSingleFull;
        uint256[] memory pointers;
        assembly ("memory-safe") {
            pointers := operandHandlers
        }
        bytes memory operandHandlerPointers = LibConvert.unsafeTo16BitBytes(pointers);

        (bytes memory bytecode, bytes32[] memory constants) = LibParseState.newState(
                bytes("a _:1 2,b:a,:c(),d:3,e:d;"),
                parseMeta,
                operandHandlerPointers,
                LibAllStandardOps.literalParserFunctionPointers()
            ).parse();
        assertEq(
            bytecode,
            // 2 sources.
            hex"01"
            // offset 0
            hex"0000"
            // 6 ops
            hex"06"
            // 5 stack allocation
            hex"05"
            // 0 input
            hex"00"
            // 5 output
            hex"05"
            // constant 0
            hex"01100000"
            // constant 1
            hex"01100001"
            // stack 0
            hex"00100000"
            // c
            hex"02000000"
            // constant 2
            hex"01100002"
            // stack 3
            hex"00100003"
        );
        assertEq(constants.length, 3);
        assertEq(constants[0], Float.unwrap(LibDecimalFloat.packLossless(1, 0)));
        assertEq(constants[1], Float.unwrap(LibDecimalFloat.packLossless(2, 0)));
        assertEq(constants[2], Float.unwrap(LibDecimalFloat.packLossless(3, 0)));
    }

    /// Stack name as the sole item on RHS of a line.
    function testParseNamedLHSStackNameOnly() external view {
        (bytes memory bytecode, bytes32[] memory constants) =
            LibParseState.newState("a:1,b:a;", "", "", LibAllStandardOps.literalParserFunctionPointers()).parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // offset 0
            hex"0000"
            // 2 ops
            hex"02"
            // 2 stack allocation
            hex"02"
            // 0 input
            hex"00"
            // 2 output
            hex"02"
            // constant 0
            hex"01100000"
            // stack 0
            hex"00100000"
        );
        assertEq(constants.length, 1);
        assertEq(constants[0], Float.unwrap(LibDecimalFloat.packLossless(1, 0)));
    }

    /// Stack name at the last position on RHS after other items.
    function testParseNamedLHSStackNameLastPosition() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibParseState.newState(
                "a _:1 2,b c:3 a;", "", "", LibAllStandardOps.literalParserFunctionPointers()
            ).parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // offset 0
            hex"0000"
            // 4 ops
            hex"04"
            // 4 stack allocation
            hex"04"
            // 0 input
            hex"00"
            // 4 output
            hex"04"
            // constant 0
            hex"01100000"
            // constant 1
            hex"01100001"
            // constant 2
            hex"01100002"
            // stack 0
            hex"00100000"
        );
        assertEq(constants.length, 3);
        assertEq(constants[0], Float.unwrap(LibDecimalFloat.packLossless(1, 0)));
        assertEq(constants[1], Float.unwrap(LibDecimalFloat.packLossless(2, 0)));
        assertEq(constants[2], Float.unwrap(LibDecimalFloat.packLossless(3, 0)));
    }

    /// Duplicate names are disallowed in the same source.
    function testParseNamedErrorDuplicateSameSource() external {
        vm.expectRevert(abi.encodeWithSelector(DuplicateLHSItem.selector, LibParseError.tagErrorOffset(4)));
        this.parseExternal("a:,a:;");
    }

    /// Duplicate names are allowed across different sources.
    function testParseNamedDuplicateDifferentSource() external view {
        (bytes memory bytecode, bytes32[] memory constants) = LibParseState.newState(
                "a b:1 2, e:a;c d:3 4,e:d;", "", "", LibAllStandardOps.literalParserFunctionPointers()
            ).parse();
        assertEq(
            bytecode,
            // 2 sources.
            hex"02"
            // offset 0
            hex"0000"
            // offset 16
            hex"0010"
            // 3 ops
            hex"03"
            // 3 stack allocation
            hex"03"
            // 0 input
            hex"00"
            // 3 output
            hex"03"
            // constant 0
            hex"01100000"
            // constant 1
            hex"01100001"
            // stack 0
            hex"00100000"
            // 3 ops
            hex"03"
            // 1 stack allocation
            hex"03"
            // 0 input
            hex"00"
            // 3 outputs
            hex"03"
            // constant 2
            hex"01100002"
            // constant 3
            hex"01100003"
            // stack 1
            hex"00100001"
        );
        assertEq(constants.length, 4);
        assertEq(constants[0], Float.unwrap(LibDecimalFloat.packLossless(1, 0)));
        assertEq(constants[1], Float.unwrap(LibDecimalFloat.packLossless(2, 0)));
        assertEq(constants[2], Float.unwrap(LibDecimalFloat.packLossless(3, 0)));
        assertEq(constants[3], Float.unwrap(LibDecimalFloat.packLossless(4, 0)));
    }
}
