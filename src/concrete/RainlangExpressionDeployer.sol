// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {IParserV2} from "rain.interpreter.interface/interface/IParserV2.sol";
import {IParserPragmaV1, PragmaV1} from "rain.interpreter.interface/interface/IParserPragmaV1.sol";

import {IDescribedByMetaV1} from "rain.metadata/interface/IDescribedByMetaV1.sol";

import {LibIntegrityCheck} from "../lib/integrity/LibIntegrityCheck.sol";
import {LibInterpreterStateDataContract} from "../lib/state/LibInterpreterStateDataContract.sol";
import {LibAllStandardOps} from "../lib/op/LibAllStandardOps.sol";
import {
    INTEGRITY_FUNCTION_POINTERS,
    DESCRIBED_BY_META_HASH
} from "../generated/RainlangExpressionDeployer.pointers.sol";
import {IIntegrityToolingV1} from "rain.sol.codegen/interface/IIntegrityToolingV1.sol";
import {RainlangParser} from "./RainlangParser.sol";
import {LibInterpreterDeploy} from "../lib/deploy/LibInterpreterDeploy.sol";

/// @title RainlangExpressionDeployer
/// @notice Coordinates parse, integrity check, and serialization for
/// deploying Rainlang expressions.
contract RainlangExpressionDeployer is
    IDescribedByMetaV1,
    IParserV2,
    IParserPragmaV1,
    IIntegrityToolingV1,
    ERC165
{
    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IDescribedByMetaV1).interfaceId || interfaceId == type(IParserV2).interfaceId
            || interfaceId == type(IParserPragmaV1).interfaceId || interfaceId == type(IIntegrityToolingV1).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IParserV2
    function parse2(bytes memory data) external view virtual override returns (bytes memory) {
        (bytes memory bytecode, bytes32[] memory constants) =
            RainlangParser(LibInterpreterDeploy.PARSER_DEPLOYED_ADDRESS).unsafeParse(data);

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

        bytes memory io = LibIntegrityCheck.integrityCheck2(INTEGRITY_FUNCTION_POINTERS, bytecode, constants);
        // Nothing is done with IO in IParserV2.
        (io);

        return serialized;
    }

    /// @notice This is just here for convenience for `IParserV2` consumers, it would be
    /// more gas efficient to call the parser directly.
    /// @inheritdoc IParserPragmaV1
    function parsePragma1(bytes calldata data) external view virtual override returns (PragmaV1 memory) {
        // The parser at the deterministic Zoltu address is also an
        // IParserPragmaV1.
        return RainlangParser(LibInterpreterDeploy.PARSER_DEPLOYED_ADDRESS).parsePragma1(data);
    }

    /// @inheritdoc IIntegrityToolingV1
    function buildIntegrityFunctionPointers() external view virtual override returns (bytes memory) {
        return LibAllStandardOps.integrityFunctionPointers();
    }

    /// @inheritdoc IDescribedByMetaV1
    function describedByMetaV1() external pure virtual override returns (bytes32) {
        return DESCRIBED_BY_META_HASH;
    }
}
