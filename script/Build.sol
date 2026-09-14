// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Script} from "forge-std-1.16.2/src/Script.sol";
import {LibCodeGen} from "rain-sol-codegen-0.1.37/src/lib/LibCodeGen.sol";
import {LibFs} from "rain-sol-codegen-0.1.37/src/lib/LibFs.sol";
import {LibGenParseMeta} from "rainlang-interface-0.2.9/src/lib/codegen/LibGenParseMeta.sol";
import {
    RainlangReferenceExtern,
    LibRainlangReferenceExtern,
    EXTERN_PARSE_META_BUILD_DEPTH
} from "../src/concrete/extern/RainlangReferenceExtern.sol";

/// @title Build
/// @notice Generates `src/generated/RainlangReferenceExternPointers.sol`, the
/// only generated file in the library: the reference extern's described-by
/// meta hash, parse meta, sub-parser word parsers, operand handlers, literal
/// parsers, integrity pointers and opcode pointers, read back off a fresh
/// instance. The deployed contracts' tables and deploy records are generated
/// in `rainlang.deploy`.
contract Build is Script {
    function run() external {
        RainlangReferenceExtern extern = new RainlangReferenceExtern();
        LibFs.buildFileForContract(
            vm,
            address(extern),
            "RainlangReferenceExternPointers",
            string.concat(
                string.concat(
                    LibCodeGen.describedByMetaHashConstantString(vm, "RainlangReferenceExtern"),
                    LibGenParseMeta.parseMetaConstantString(
                        vm, LibRainlangReferenceExtern.authoringMetaV2(), EXTERN_PARSE_META_BUILD_DEPTH
                    ),
                    LibCodeGen.subParserWordParsersConstantString(vm, extern)
                ),
                string.concat(
                    LibCodeGen.operandHandlerFunctionPointersConstantString(vm, extern),
                    LibCodeGen.literalParserFunctionPointersConstantString(vm, extern),
                    LibCodeGen.integrityFunctionPointersConstantString(vm, extern),
                    LibCodeGen.opcodeFunctionPointersConstantString(vm, extern)
                )
            )
        );
    }
}
