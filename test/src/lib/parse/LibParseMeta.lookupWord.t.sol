// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibParseMeta} from "rain-interpreter-interface-0.1.0/src/lib/parse/LibParseMeta.sol";
import {LibGenParseMeta} from "rain-interpreter-interface-0.1.0/src/lib/codegen/LibGenParseMeta.sol";
import {AuthoringMetaV2} from "rain-interpreter-interface-0.1.0/src/interface/IParserV2.sol";

/// @title LibParseMetaLookupWordTest
/// @notice Tests LibParseMeta's lookupWord function as consumed by the rainlang
/// parser. lookupWord resolves a word string to its opcode index against the
/// parse meta produced by LibGenParseMeta.buildParseMetaV2.
contract LibParseMetaLookupWordTest is Test {
    /// Build meta from a set of known words. Each word resolves as found and
    /// returns the index that matches its position in the authoring meta.
    function testLibParseMetaLookupWordKnown() external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](3);
        metas[0] = AuthoringMetaV2({word: bytes32("add"), description: ""});
        metas[1] = AuthoringMetaV2({word: bytes32("sub"), description: ""});
        metas[2] = AuthoringMetaV2({word: bytes32("mul"), description: ""});

        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 8);

        (bool existsAdd, uint256 indexAdd) = LibParseMeta.lookupWord(meta, bytes32("add"));
        assertTrue(existsAdd, "add should exist");
        assertEq(indexAdd, 0, "add index");

        (bool existsSub, uint256 indexSub) = LibParseMeta.lookupWord(meta, bytes32("sub"));
        assertTrue(existsSub, "sub should exist");
        assertEq(indexSub, 1, "sub index");

        (bool existsMul, uint256 indexMul) = LibParseMeta.lookupWord(meta, bytes32("mul"));
        assertTrue(existsMul, "mul should exist");
        assertEq(indexMul, 2, "mul index");
    }

    /// A word that was not built into the meta resolves as not found, with an
    /// index of zero.
    function testLibParseMetaLookupWordNotFound() external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](3);
        metas[0] = AuthoringMetaV2({word: bytes32("add"), description: ""});
        metas[1] = AuthoringMetaV2({word: bytes32("sub"), description: ""});
        metas[2] = AuthoringMetaV2({word: bytes32("mul"), description: ""});

        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 8);

        (bool exists, uint256 index) = LibParseMeta.lookupWord(meta, bytes32("notaword"));
        assertFalse(exists, "notaword should not exist");
        assertEq(index, 0, "not found index is zero");
    }

    /// A single word at a single depth resolves as found at index zero, and an
    /// unrelated word resolves as not found.
    function testLibParseMetaLookupWordSingleDepth() external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](1);
        metas[0] = AuthoringMetaV2({word: bytes32("only"), description: ""});

        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 1);

        (bool exists, uint256 index) = LibParseMeta.lookupWord(meta, bytes32("only"));
        assertTrue(exists, "only should exist");
        assertEq(index, 0, "only index");

        (bool notExists, uint256 notIndex) = LibParseMeta.lookupWord(meta, bytes32("other"));
        assertFalse(notExists, "other should not exist");
        assertEq(notIndex, 0, "not found index is zero");
    }

    /// Fuzz: every word built into the meta resolves as found at its authoring
    /// index, and a word not built into the meta resolves as not found.
    function testLibParseMetaLookupWordRoundtripFuzz(bytes32 wordA, bytes32 wordB, bytes32 notFound) external pure {
        // Distinct, non-zero words so the meta builds without duplicate words.
        vm.assume(wordA != bytes32(0) && wordB != bytes32(0));
        vm.assume(wordA != wordB);
        vm.assume(notFound != wordA && notFound != wordB);

        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](2);
        metas[0] = AuthoringMetaV2({word: wordA, description: ""});
        metas[1] = AuthoringMetaV2({word: wordB, description: ""});

        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 3);

        (bool existsA, uint256 indexA) = LibParseMeta.lookupWord(meta, wordA);
        assertTrue(existsA, "wordA should exist");
        assertEq(indexA, 0, "wordA index");

        (bool existsB, uint256 indexB) = LibParseMeta.lookupWord(meta, wordB);
        assertTrue(existsB, "wordB should exist");
        assertEq(indexB, 1, "wordB index");

        (bool existsNotFound, uint256 indexNotFound) = LibParseMeta.lookupWord(meta, notFound);
        assertFalse(existsNotFound, "notFound should not exist");
        assertEq(indexNotFound, 0, "not found index is zero");
    }
}
