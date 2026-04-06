// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Script} from "forge-std/Script.sol";
import {RainlangInterpreter} from "../src/concrete/RainlangInterpreter.sol";
import {RainlangStore} from "../src/concrete/RainlangStore.sol";
import {RainlangParser, PARSE_META_BUILD_DEPTH} from "../src/concrete/RainlangParser.sol";
import {RainlangExpressionDeployer} from "../src/concrete/RainlangExpressionDeployer.sol";
import {Rainlang} from "../src/concrete/Rainlang.sol";
import {
    RainlangReferenceExtern,
    LibRainlangReferenceExtern,
    EXTERN_PARSE_META_BUILD_DEPTH
} from "../src/concrete/extern/RainlangReferenceExtern.sol";
import {LibAllStandardOps} from "../src/lib/op/LibAllStandardOps.sol";
import {LibCodeGen} from "rain.sol.codegen/lib/LibCodeGen.sol";
import {LibGenParseMeta} from "rain.interpreter.interface/lib/codegen/LibGenParseMeta.sol";
import {LibFs} from "rain.sol.codegen/lib/LibFs.sol";
import {LibRainDeploy} from "rain.deploy/lib/LibRainDeploy.sol";

/// @title BuildPointers
/// @notice Forge script that generates Solidity source files containing
/// precomputed constant values (bytecode hashes, function pointer tables,
/// parse meta, deterministic deploy addresses) for each concrete contract.
/// Run via `forge script` during the build step. Each `build*` function
/// deploys the contract via the Zoltu factory in a local EVM, extracts its
/// runtime pointers, and writes a `.pointers.sol` file into `src/generated/`.
contract BuildPointers is Script {
    /// @notice Generates a Solidity address constant declaration string.
    /// @param addr The address value.
    /// @return A string containing the Solidity code for the address constant.
    function addressConstantString(address addr) internal view returns (string memory) {
        return string.concat(
            "\n",
            "/// @dev The deterministic deploy address of the contract when deployed via\n",
            "/// the Zoltu factory.\n",
            "address constant DEPLOYED_ADDRESS = address(",
            vm.toString(addr),
            ");\n"
        );
    }

    /// Builds the RainlangInterpreter opcode function pointer table.
    function buildRainlangInterpreterPointers() internal {
        address deployed = LibRainDeploy.deployZoltu(type(RainlangInterpreter).creationCode);
        RainlangInterpreter interpreter = RainlangInterpreter(deployed);

        LibFs.buildFileForContract(
            vm,
            deployed,
            "RainlangInterpreter",
            string.concat(
                addressConstantString(deployed),
                LibCodeGen.bytesConstantString(
                    vm,
                    "/// @dev The creation bytecode of the contract.",
                    "CREATION_CODE",
                    type(RainlangInterpreter).creationCode
                ),
                LibCodeGen.bytesConstantString(
                    vm, "/// @dev The runtime bytecode of the contract.", "RUNTIME_CODE", deployed.code
                ),
                LibCodeGen.opcodeFunctionPointersConstantString(vm, interpreter)
            )
        );
    }

    /// Builds the RainlangStore pointer file.
    function buildRainlangStorePointers() internal {
        address deployed = LibRainDeploy.deployZoltu(type(RainlangStore).creationCode);

        LibFs.buildFileForContract(
            vm,
            deployed,
            "RainlangStore",
            string.concat(
                addressConstantString(deployed),
                LibCodeGen.bytesConstantString(
                    vm,
                    "/// @dev The creation bytecode of the contract.",
                    "CREATION_CODE",
                    type(RainlangStore).creationCode
                ),
                LibCodeGen.bytesConstantString(
                    vm, "/// @dev The runtime bytecode of the contract.", "RUNTIME_CODE", deployed.code
                )
            )
        );
    }

    /// Builds the RainlangParser pointer file including the parse meta
    /// (generated from `authoringMetaV2`), operand handler pointers, and
    /// literal parser pointers.
    function buildRainlangParserPointers() internal {
        address deployed = LibRainDeploy.deployZoltu(type(RainlangParser).creationCode);
        RainlangParser parser = RainlangParser(deployed);

        LibFs.buildFileForContract(
            vm,
            deployed,
            "RainlangParser",
            string.concat(
                string.concat(
                    addressConstantString(deployed),
                    LibCodeGen.bytesConstantString(
                        vm,
                        "/// @dev The creation bytecode of the contract.",
                        "CREATION_CODE",
                        type(RainlangParser).creationCode
                    ),
                    LibCodeGen.bytesConstantString(
                        vm, "/// @dev The runtime bytecode of the contract.", "RUNTIME_CODE", deployed.code
                    )
                ),
                string.concat(
                    LibGenParseMeta.parseMetaConstantString(
                        vm, LibAllStandardOps.authoringMetaV2(), PARSE_META_BUILD_DEPTH
                    ),
                    LibCodeGen.operandHandlerFunctionPointersConstantString(vm, parser),
                    LibCodeGen.literalParserFunctionPointersConstantString(vm, parser)
                )
            )
        );
    }

    /// Builds the RainlangExpressionDeployer pointer file including
    /// the described-by meta hash and integrity function pointers.
    function buildRainlangExpressionDeployerPointers() internal {
        address deployed = LibRainDeploy.deployZoltu(type(RainlangExpressionDeployer).creationCode);
        RainlangExpressionDeployer deployer = RainlangExpressionDeployer(deployed);

        string memory name = "RainlangExpressionDeployer";

        LibFs.buildFileForContract(
            vm,
            deployed,
            name,
            string.concat(
                string.concat(
                    addressConstantString(deployed),
                    LibCodeGen.bytesConstantString(
                        vm,
                        "/// @dev The creation bytecode of the contract.",
                        "CREATION_CODE",
                        type(RainlangExpressionDeployer).creationCode
                    ),
                    LibCodeGen.bytesConstantString(
                        vm, "/// @dev The runtime bytecode of the contract.", "RUNTIME_CODE", deployed.code
                    )
                ),
                string.concat(
                    LibCodeGen.describedByMetaHashConstantString(vm, name),
                    LibCodeGen.integrityFunctionPointersConstantString(vm, deployer)
                )
            )
        );
    }

    /// Builds the RainlangReferenceExtern pointer file including
    /// described-by meta hash, parse meta, sub-parser word parsers, operand
    /// handlers, literal parsers, integrity pointers, and opcode pointers.
    function buildRainlangReferenceExternPointers() internal {
        address deployed = LibRainDeploy.deployZoltu(type(RainlangReferenceExtern).creationCode);
        RainlangReferenceExtern extern = RainlangReferenceExtern(deployed);

        string memory name = "RainlangReferenceExtern";

        LibFs.buildFileForContract(
            vm,
            deployed,
            name,
            string.concat(
                string.concat(
                    addressConstantString(deployed),
                    LibCodeGen.bytesConstantString(
                        vm,
                        "/// @dev The creation bytecode of the contract.",
                        "CREATION_CODE",
                        type(RainlangReferenceExtern).creationCode
                    ),
                    LibCodeGen.bytesConstantString(
                        vm, "/// @dev The runtime bytecode of the contract.", "RUNTIME_CODE", deployed.code
                    ),
                    LibCodeGen.describedByMetaHashConstantString(vm, name)
                ),
                string.concat(
                    LibGenParseMeta.parseMetaConstantString(
                        vm, LibRainlangReferenceExtern.authoringMetaV2(), EXTERN_PARSE_META_BUILD_DEPTH
                    ),
                    LibCodeGen.subParserWordParsersConstantString(vm, extern),
                    LibCodeGen.operandHandlerFunctionPointersConstantString(vm, extern),
                    LibCodeGen.literalParserFunctionPointersConstantString(vm, extern)
                ),
                string.concat(
                    LibCodeGen.integrityFunctionPointersConstantString(vm, extern),
                    LibCodeGen.opcodeFunctionPointersConstantString(vm, extern)
                )
            )
        );
    }

    /// Builds the Rainlang pointer file.
    function buildRainlangPointers() internal {
        address deployed = LibRainDeploy.deployZoltu(type(Rainlang).creationCode);

        LibFs.buildFileForContract(
            vm,
            deployed,
            "Rainlang",
            string.concat(
                addressConstantString(deployed),
                LibCodeGen.bytesConstantString(
                    vm, "/// @dev The creation bytecode of the contract.", "CREATION_CODE", type(Rainlang).creationCode
                ),
                LibCodeGen.bytesConstantString(
                    vm, "/// @dev The runtime bytecode of the contract.", "RUNTIME_CODE", deployed.code
                )
            )
        );
    }

    /// Entry point. Etches the Zoltu factory and builds all pointer files.
    function run() external {
        LibRainDeploy.etchZoltuFactory(vm);

        buildRainlangInterpreterPointers();
        buildRainlangStorePointers();
        buildRainlangParserPointers();
        buildRainlangExpressionDeployerPointers();
        buildRainlangReferenceExternPointers();
        buildRainlangPointers();
    }
}
