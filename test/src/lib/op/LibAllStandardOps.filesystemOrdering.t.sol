// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibAllStandardOps, ALL_STANDARD_OPS_LENGTH} from "../../../../src/lib/op/LibAllStandardOps.sol";
import {AuthoringMetaV2} from "rain.interpreter.interface/interface/IParserV2.sol";
import {LibCamelToKebab} from "test/lib/string/LibCamelToKebab.sol";

/// @title LibAllStandardOpsFilesystemOrderingTest
/// @notice Verifies that authoring meta word names (indices 4+) match the
/// filesystem ordering of LibOp*.sol files. The first 4 opcodes (stack,
/// constant, extern, context) have a fixed order for parsing and are excluded.
/// Alias words (multiple words sharing a single file, e.g. "now" aliasing
/// "block-timestamp") are skipped in the comparison.
contract LibAllStandardOpsFilesystemOrderingTest is Test {
    /// Authoring meta words at indices 4+ must match the filesystem ordering
    /// of LibOp*.sol files when converted from CamelCase to kebab-case.
    function testAuthoringMetaMatchesFilesystemOrdering() external {
        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-c";
        cmd[2] = "find src/lib/op -name 'LibOp*.sol' " "-not -name 'LibAllStandardOps.sol' "
            "-not -name 'LibOpConstant.sol' " "-not -name 'LibOpContext.sol' " "-not -name 'LibOpExtern.sol' "
            "-not -name 'LibOpStack.sol' " "| LC_ALL=C sort "
            "| while read f; do basename \"$f\" .sol | sed 's/^LibOp//'; done";
        bytes memory raw = vm.ffi(cmd);

        bytes memory authoringMeta = LibAllStandardOps.authoringMetaV2();
        AuthoringMetaV2[] memory words = abi.decode(authoringMeta, (AuthoringMetaV2[]));

        // Walk both lists in parallel. When a word is an alias (does not
        // correspond to its own file), skip it in the word list.
        // vm.ffi() trims trailing whitespace so the last entry may lack a
        // trailing newline — handle that with a final segment check.
        uint256 start;
        uint256 wordIdx = 4;
        for (uint256 i; i <= raw.length; i++) {
            bool isEnd = i == raw.length;
            bool isNewline = !isEnd && raw[i] == 0x0a;
            if (!isNewline && !isEnd) continue;
            if (i == start) {
                // Empty line.
                start = i + 1;
                continue;
            }
            bytes memory segment = new bytes(i - start);
            for (uint256 j; j < segment.length; j++) {
                segment[j] = raw[start + j];
            }
            string memory camelName = string(segment);
            string memory kebab = LibCamelToKebab.camelToKebab(camelName);

            // Skip alias words that share a file with the previous word.
            while (wordIdx < words.length && isAlias(words[wordIdx].word)) {
                wordIdx++;
            }
            assertTrue(wordIdx < words.length, "more files than words");

            string memory word = bytes32ToString(words[wordIdx].word);
            assertEq(
                word,
                kebab,
                string.concat(
                    "word[", vm.toString(wordIdx), "] '", word, "' != file '", camelName, "' -> '", kebab, "'"
                )
            );
            wordIdx++;
            start = i + 1;
        }

        // After matching all files, only alias words should remain.
        while (wordIdx < words.length) {
            assertTrue(
                isAlias(words[wordIdx].word), string.concat("trailing non-alias word[", vm.toString(wordIdx), "]")
            );
            wordIdx++;
        }
    }

    /// @notice Returns true if the word is a known alias (shares a file with
    /// another word). Currently only "now" (alias for "block-timestamp").
    function isAlias(bytes32 word) internal pure returns (bool) {
        // "now" is 3 bytes; left-aligning into bytes32 is safe.
        //forge-lint: disable-next-line(unsafe-typecast)
        return word == bytes32("now");
    }

    function bytes32ToString(bytes32 b) internal pure returns (string memory) {
        uint256 len;
        for (len = 0; len < 32; len++) {
            if (b[len] == 0) break;
        }
        bytes memory s = new bytes(len);
        for (uint256 i; i < len; i++) {
            s[i] = b[i];
        }
        return string(s);
    }
}
