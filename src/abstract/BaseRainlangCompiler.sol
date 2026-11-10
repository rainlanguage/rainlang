// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ERC165} from "@openzeppelin-contracts-5.7.0/utils/introspection/ERC165.sol";
import {Pointer} from "rain-solmem-0.1.28/src/lib/LibPointer.sol";
import {IParserV2} from "../interface/IParserV2.sol";
import {IParserDotrainV1, DotrainBinding} from "../interface/IParserDotrainV1.sol";
import {LibDotrainCompose} from "../lib/dotrain/LibDotrainCompose.sol";
import {IParserPragmaV1, PragmaV1} from "../interface/IParserPragmaV1.sol";

import {IDescribedByMetaV1} from "rain-metadata-0.1.45/src/interface/IDescribedByMetaV1.sol";

import {LibIntegrityCheck} from "../lib/integrity/LibIntegrityCheck.sol";
import {LibInterpreterStateDataContract} from "../lib/state/LibInterpreterStateDataContract.sol";
import {LibAllStandardOps} from "../lib/op/LibAllStandardOps.sol";
import {IIntegrityToolingV1} from "rain-sol-codegen-0.1.39/src/interface/IIntegrityToolingV1.sol";
import {BaseRainlangParser} from "./BaseRainlangParser.sol";

/// @title BaseRainlangCompiler
/// @notice Coordinates parse, integrity check, and serialization for
/// compiling Rainlang expressions. Everything except the parser it delegates
/// to, the integrity function pointer table and the described-by meta hash,
/// which a concrete binds by overriding `parser`, `integrityFunctionPointers`
/// and `describedByMetaV1`.
abstract contract BaseRainlangCompiler is
    IDescribedByMetaV1,
    IParserV2,
    IParserDotrainV1,
    IParserPragmaV1,
    IIntegrityToolingV1,
    ERC165
{
    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IDescribedByMetaV1).interfaceId || interfaceId == type(IParserV2).interfaceId
            || interfaceId == type(IParserDotrainV1).interfaceId || interfaceId == type(IParserPragmaV1).interfaceId
            || interfaceId == type(IIntegrityToolingV1).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @notice The parser `parse2` and `parsePragma1` delegate to.
    /// @return The parser.
    function parser() internal view virtual returns (BaseRainlangParser);

    /// @notice The integrity function pointers `parse2` checks bytecode
    /// against.
    /// @return The packed integrity function pointers.
    function integrityFunctionPointers() internal view virtual returns (bytes memory);

    /// @inheritdoc IParserV2
    function parse2(bytes memory data) external view virtual override returns (bytes memory) {
        return compile(data);
    }

    /// @inheritdoc IParserDotrainV1
    function parseDotrain2(string memory dotrain, string memory entrypoint, DotrainBinding[] memory bindings)
        external
        view
        virtual
        override
        returns (bytes memory)
    {
        return compile(bytes(LibDotrainCompose.compose(dotrain, entrypoint, bindings)));
    }

    /// @notice Parses, serializes and integrity checks `data`.
    /// @param data The Rainlang source to compile.
    /// @return The serialized bytecode.
    function compile(bytes memory data) internal view returns (bytes memory) {
        (bytes memory bytecode, bytes32[] memory constants) = parser().unsafeParse(data);

        uint256 size = LibInterpreterStateDataContract.serializeSize(bytecode, constants);
        bytes memory serialized;
        Pointer cursor;
        assembly ("memory-safe") {
            serialized := mload(0x40)
            mstore(0x40, add(serialized, add(0x20, size)))
            mstore(serialized, size)
            cursor := add(serialized, 0x20)
        }
        LibInterpreterStateDataContract.unsafeSerialize(cursor, bytecode, constants);

        bytes memory io = LibIntegrityCheck.integrityCheck2(integrityFunctionPointers(), bytecode, constants);
        // Nothing is done with IO in IParserV2.
        (io);

        return serialized;
    }

    /// @notice This is just here for convenience for `IParserV2` consumers, it would be
    /// more gas efficient to call the parser directly.
    /// @inheritdoc IParserPragmaV1
    function parsePragma1(bytes calldata data) external view virtual override returns (PragmaV1 memory) {
        // The parser is also an IParserPragmaV1.
        return parser().parsePragma1(data);
    }

    /// @inheritdoc IIntegrityToolingV1
    function buildIntegrityFunctionPointers() external view virtual override returns (bytes memory) {
        return LibAllStandardOps.integrityFunctionPointers();
    }
}
