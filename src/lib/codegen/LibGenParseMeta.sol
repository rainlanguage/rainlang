// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {AuthoringMetaV2} from "../../interface/IParserV2.sol";
import {
    META_ITEM_SIZE,
    FINGERPRINT_MASK,
    META_EXPANSION_SIZE,
    META_PREFIX_SIZE,
    LibParseMeta
} from "../parse/LibParseMeta.sol";
import {LibCtPop} from "rain-math-binary-0.1.4/src/lib/LibCtPop.sol";
import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {LibCodeGen} from "rain-sol-codegen-0.1.39/src/lib/LibCodeGen.sol";

uint256 constant META_ITEM_MASK = type(uint32).max;

/// @dev For metadata builder.
error DuplicateFingerprint();

/// @dev Thrown when the authoring meta exceeds 256 words. Opcode indices are
/// stored in a single byte, so more than 256 words cannot be represented.
error AuthoringMetaTooLarge(uint256 length);

/// @dev Thrown when the authoring meta cannot be compressed within the
/// provided maxDepth bloom filter layers.
error MaxDepthExceeded(uint8 maxDepth);

/// @title LibGenParseMeta
/// @notice Library for building parse meta from authoring meta, and generating
/// constant strings for the parse meta to be used in generated code. The parse
/// meta is a bytes array that is used to lookup word definitions. The parse meta
/// is built from the authoring meta, which is an array of `AuthoringMetaV2` that
/// contains the word and its corresponding opcode index. The parse meta is
/// structured in a way that allows for efficient lookups of word definitions
/// using bloom filters and fingerprints. The library provides functions to find
/// the best expander for a given set of authoring meta, build the parse meta
/// from the authoring meta and build depth, and generate a constant string for
/// the parse meta with a comment describing its structure. The main purpose of
/// this library is to optimize the size of the parse meta while maintaining
/// efficient lookups, which is important for the performance of the interpreter.
library LibGenParseMeta {
    /// @dev Finds the best expander for a given set of authoring meta. The best
    /// expander is the one that produces the densest bloom filter at each depth,
    /// which minimizes the number of items that need to be checked for each
    /// lookup. The function returns the best seed, the corresponding expansion,
    /// and the remaining authoring meta that could not be expanded with this
    /// seed. The remaining authoring meta can then be used to find the next best
    /// expander until all authoring meta has been expanded.
    /// @param metas The authoring meta to find the best expander for.
    /// @return bestSeed The best seed for the given authoring meta.
    /// @return bestExpansion The corresponding expansion for the best seed.
    /// @return remaining The remaining authoring meta that could not be expanded
    /// with the best seed.
    function findBestExpander(AuthoringMetaV2[] memory metas)
        internal
        pure
        returns (uint8 bestSeed, uint256 bestExpansion, AuthoringMetaV2[] memory remaining)
    {
        unchecked {
            {
                uint256 bestCt = 0;
                for (uint256 seed = 0; seed <= type(uint8).max; seed++) {
                    uint256 expansion = 0;
                    for (uint256 i = 0; i < metas.length; i++) {
                        //slither-disable-next-line unused-return
                        (uint256 shifted,) = LibParseMeta.wordBitmapped(seed, metas[i].word);
                        expansion = shifted | expansion;
                    }
                    uint256 ct = LibCtPop.ctpop(expansion);
                    if (ct > bestCt) {
                        bestCt = ct;
                        // Seed is within 1 byte.
                        //forge-lint: disable-next-line(unsafe-typecast)
                        bestSeed = uint8(seed);
                        bestExpansion = expansion;
                    }
                    // perfect expansion.
                    if (ct == metas.length) {
                        break;
                    }
                }

                uint256 remainingLength = metas.length - bestCt;
                assembly ("memory-safe") {
                    remaining := mload(0x40)
                    mstore(remaining, remainingLength)
                    mstore(0x40, add(remaining, mul(0x20, add(1, remainingLength))))
                }
            }
            uint256 usedExpansion = 0;
            uint256 j = 0;
            for (uint256 i = 0; i < metas.length; i++) {
                //slither-disable-next-line unused-return
                (uint256 shifted,) = LibParseMeta.wordBitmapped(bestSeed, metas[i].word);
                if ((shifted & usedExpansion) == 0) {
                    usedExpansion = shifted | usedExpansion;
                } else {
                    remaining[j] = metas[i];
                    j++;
                }
            }
        }
    }

    /// @dev Builds the parse meta from the authoring meta and build depth. The
    /// parse meta is a bytes array with the following structure:
    /// - 1 byte: The depth of the bloom filters
    /// - 1 byte: The hashing seed
    /// - The bloom filters, each is 32 bytes long, one for each build depth
    /// - All the items for each word, each is 4 bytes long. Each item's first
    ///   byte is its opcode index, the remaining 3 bytes are the word
    ///   fingerprint.
    /// The parse meta is used to lookup word definitions. To do a lookup, the
    /// word is hashed with the seed, then the first byte of the hash selects a
    /// bit in the bloom filter. If the bit is not set, the word is not in the
    /// set — return immediately. If the bit is set, we count the number of 1
    /// bits in the bloom filter below this item's bit. We then treat this as
    /// the index of the item in the items array. We then compare the word
    /// fingerprint against the fingerprint of the item at this index. If the
    /// fingerprints equal then we have a match, else we increment the seed and
    /// try again with the next bloom filter, offsetting all the indexes by the
    /// total bit count of the previous bloom filter. If we reach the end of the
    /// bloom filters then we have a miss.
    /// The output is validated via `LibParseMeta.checkParseMetaStructure`
    /// before returning. Reverts with `MaxDepthExceeded` if the words cannot
    /// be compressed within `maxDepth` layers, or `AuthoringMetaTooLarge` if
    /// there are more than 256 words.
    /// @param authoringMeta The authoring meta to build the parse meta from.
    /// @param maxDepth The maximum depth of the bloom filters to use. This is a
    /// tradeoff between the size of the parse meta and the speed of lookups. The
    /// main reason to increase the depth is during generation there may be an
    /// unresolvable collision at a certain depth, so we need to increase the
    /// depth to resolve it.
    /// @return parseMeta The parse meta built from the authoring meta and build
    /// depth.
    function buildParseMetaV2(AuthoringMetaV2[] memory authoringMeta, uint8 maxDepth)
        internal
        pure
        returns (bytes memory parseMeta)
    {
        unchecked {
            // Opcode index is stored in a single byte, so we cannot handle
            // more than 256 words.
            if (authoringMeta.length > 256) {
                revert AuthoringMetaTooLarge(authoringMeta.length);
            }
            // Write out expansions.
            uint8[] memory seeds;
            uint256[] memory expansions;
            uint256 dataStart;
            {
                uint256 depth = 0;
                seeds = new uint8[](maxDepth);
                expansions = new uint256[](maxDepth);
                {
                    AuthoringMetaV2[] memory remainingAuthoringMeta = authoringMeta;
                    while (remainingAuthoringMeta.length > 0) {
                        if (depth >= maxDepth) {
                            revert MaxDepthExceeded(maxDepth);
                        }
                        uint8 seed;
                        uint256 expansion;
                        (seed, expansion, remainingAuthoringMeta) = findBestExpander(remainingAuthoringMeta);
                        seeds[depth] = seed;
                        expansions[depth] = expansion;
                        depth++;
                    }
                }

                uint256 parseMetaLength =
                    META_PREFIX_SIZE + depth * META_EXPANSION_SIZE + authoringMeta.length * META_ITEM_SIZE;
                parseMeta = new bytes(parseMetaLength);
                assembly ("memory-safe") {
                    mstore8(add(parseMeta, 0x20), depth)
                }
                for (uint256 j = 0; j < depth; j++) {
                    assembly ("memory-safe") {
                        // Write each seed immediately before its expansion.
                        let seedWriteAt := add(add(parseMeta, 0x21), mul(0x21, j))
                        mstore8(seedWriteAt, mload(add(seeds, add(0x20, mul(0x20, j)))))
                        mstore(add(seedWriteAt, 1), mload(add(expansions, add(0x20, mul(0x20, j)))))
                    }
                }

                {
                    // dataStart is set so that mload(dataStart + pos * META_ITEM_SIZE)
                    // places the 4-byte item at bytes 28–31 of the loaded word,
                    // matching the byte(28, ...) extraction in lookupWord.
                    // This works because the offset omits the 0x20 bytes-length
                    // prefix and adds META_ITEM_SIZE instead, creating a 28-byte
                    // backset (0x20 - META_ITEM_SIZE = 28) from the first item's
                    // actual memory address.
                    uint256 dataOffset = META_PREFIX_SIZE + META_ITEM_SIZE + depth * META_EXPANSION_SIZE;
                    assembly ("memory-safe") {
                        dataStart := add(parseMeta, dataOffset)
                    }
                }
            }

            // Write words.
            for (uint256 k = 0; k < authoringMeta.length; k++) {
                uint256 s = 0;
                uint256 cumulativePos = 0;
                while (true) {
                    uint256 toWrite;
                    uint256 writeAt;

                    // Need some careful scoping here to avoid stack too deep.
                    {
                        uint256 expansion = expansions[s];

                        uint256 hashed;
                        {
                            uint256 shifted;
                            (shifted, hashed) = LibParseMeta.wordBitmapped(seeds[s], authoringMeta[k].word);

                            uint256 metaItemSize = META_ITEM_SIZE;
                            uint256 pos = LibCtPop.ctpop(expansion & (shifted - 1)) + cumulativePos;
                            assembly ("memory-safe") {
                                writeAt := add(dataStart, mul(pos, metaItemSize))
                            }
                        }

                        {
                            uint256 wordFingerprint = hashed & FINGERPRINT_MASK;
                            uint256 posFingerprint;
                            assembly ("memory-safe") {
                                posFingerprint := mload(writeAt)
                            }
                            posFingerprint &= FINGERPRINT_MASK;
                            if (posFingerprint != 0) {
                                if (posFingerprint == wordFingerprint) {
                                    revert DuplicateFingerprint();
                                }
                                // Collision, try next expansion.
                                s++;
                                cumulativePos = cumulativePos + LibCtPop.ctpop(expansion);
                                continue;
                            }
                            // Not collision, prepare the write with the
                            // fingerprint and index.
                            toWrite = wordFingerprint | (k << 0x18);
                        }
                    }

                    uint256 mask = ~META_ITEM_MASK;
                    assembly ("memory-safe") {
                        mstore(writeAt, or(and(mload(writeAt), mask), toWrite))
                    }
                    // We're done with this word.
                    break;
                }
            }

            LibParseMeta.checkParseMetaStructure(parseMeta);
        }
    }

    /// @dev Builds a constant string containing the parse meta, which can be
    /// used in generated code. The string also includes a comment describing the
    /// structure of the parse meta for future reference.
    /// @param vm The Vm instance to use for generating the constant string.
    /// @param authoringMetaBytes The abi-encoded authoring meta to build the
    /// parse meta from.
    /// @param buildDepth The build depth to use for the parse meta.
    /// @return A constant string containing the parse meta, with a comment
    /// describing its structure.
    function parseMetaConstantString(Vm vm, bytes memory authoringMetaBytes, uint8 buildDepth)
        internal
        pure
        returns (string memory)
    {
        AuthoringMetaV2[] memory authoringMeta = abi.decode(authoringMetaBytes, (AuthoringMetaV2[]));
        return string.concat(
            LibCodeGen.bytesConstantString(
                vm,
                string.concat(
                    "/// @dev The parse meta that is used to lookup word definitions.\n",
                    "/// The structure of the parse meta is:\n",
                    "/// - 1 byte: The depth of the bloom filters\n",
                    "/// - 1 byte: The hashing seed\n",
                    "/// - The bloom filters, each is 32 bytes long, one for each build depth.\n",
                    "/// - All the items for each word, each is 4 bytes long. Each item's first byte\n",
                    "///   is its opcode index, the remaining 3 bytes are the word fingerprint.\n",
                    "/// To do a lookup, the word is hashed with the seed, then the first byte of the\n",
                    "/// hash is compared against the bloom filter. If there is a hit then we count\n",
                    "/// the number of 1 bits in the bloom filter up to this item's 1 bit. We then\n",
                    "/// treat this a the index of the item in the items array. We then compare the\n",
                    "/// word fingerprint against the fingerprint of the item at this index. If the\n",
                    "/// fingerprints equal then we have a match, else we increment the seed and try\n",
                    "/// again with the next bloom filter, offsetting all the indexes by the total\n",
                    "/// bit count of the previous bloom filter. If we reach the end of the bloom\n",
                    "/// filters then we have a miss."
                ),
                "PARSE_META",
                LibGenParseMeta.buildParseMetaV2(authoringMeta, buildDepth)
            ),
            LibCodeGen.uint8ConstantString(
                vm, "/// @dev The build depth of the parser meta.\n", "PARSE_META_BUILD_DEPTH", buildDepth
            )
        );
    }
}
