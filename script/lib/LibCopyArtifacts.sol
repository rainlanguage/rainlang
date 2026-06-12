// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.16.1/src/Vm.sol";

/// @notice Shared logic between `script/CopyArtifacts.sol` (writes the
/// committed ABI). The `copy-artifacts` CI job runs that writer then
/// `git diff --exit-code`, so the committed copies are asserted fresh by
/// the absence of drift.
library LibCopyArtifacts {
    /// @notice Contract artifacts that the Rust crates consume via
    /// alloy::sol!. Adding a new contract here also requires the Rust
    /// crate to reference it.
    function contracts() internal pure returns (string[] memory) {
        string[] memory names = new string[](11);
        names[0] = "Rainlang";
        names[1] = "RainlangExpressionDeployer";
        names[2] = "RainlangInterpreter";
        names[3] = "RainlangParser";
        names[4] = "RainlangStore";
        names[5] = "TestERC20";
        names[6] = "IExpressionDeployerV3";
        names[7] = "IInterpreterStoreV3";
        names[8] = "IInterpreterV4";
        names[9] = "IParserPragmaV1";
        names[10] = "IParserV2";
        return names;
    }

    /// @notice Path of the live forge build artifact for a contract.
    function livePath(string memory contractName) internal pure returns (string memory) {
        return string.concat("out/", contractName, ".sol/", contractName, ".json");
    }

    /// @notice Committed ABI copies that the Rust crates read at compile
    /// time. A contract may be written to more than one location: a crate
    /// that publishes to crates.io must carry its own packaged copy
    /// (`cargo publish` only includes a crate's own directory), so the
    /// `Rainlang` ABI consumed by both `bindings` and `test_fixtures` is
    /// committed to each. The interface ABIs are read only by `bindings`;
    /// the concrete contract and `TestERC20` ABIs are read only by
    /// `test_fixtures`.
    function committedPaths(string memory contractName) internal pure returns (string[] memory) {
        bytes32 name = keccak256(bytes(contractName));

        // Interfaces are consumed only by the `bindings` crate.
        if (
            name == keccak256("IExpressionDeployerV3") || name == keccak256("IInterpreterStoreV3")
                || name == keccak256("IInterpreterV4") || name == keccak256("IParserPragmaV1")
                || name == keccak256("IParserV2")
        ) {
            return _paths(string.concat("crates/bindings/abi/", contractName, ".json"));
        }

        // `Rainlang` is the discovery point consumed by both crates, so
        // each carries its own packaged copy.
        if (name == keccak256("Rainlang")) {
            string[] memory paths = new string[](2);
            paths[0] = string.concat("crates/bindings/abi/", contractName, ".json");
            paths[1] = string.concat("crates/test_fixtures/abi/", contractName, ".json");
            return paths;
        }

        // The concrete contracts and `TestERC20` are consumed only by the
        // `test_fixtures` crate.
        return _paths(string.concat("crates/test_fixtures/abi/", contractName, ".json"));
    }

    /// @notice Wraps a single path in a length-one array.
    function _paths(string memory path) private pure returns (string[] memory) {
        string[] memory paths = new string[](1);
        paths[0] = path;
        return paths;
    }

    /// @notice Extracts the deterministic subset of the live forge
    /// artifact via `jq` over `vm.ffi`. The full forge JSON is
    /// non-deterministic across machines (solc source unit IDs in
    /// `metadata.sources`, `sourceMap` and friends shift with filesystem
    /// enumeration order). The kept keys — `abi`, `bytecode.object`,
    /// `deployedBytecode.object` — are pure functions of the input source
    /// and compiler settings. alloy::sol! reads `abi` for type
    /// generation; the bytecode fields are consumed by the Rust EVM
    /// setup at runtime.
    function extractStable(Vm vm, string memory contractName) internal returns (bytes memory) {
        string[] memory cmd = new string[](3);
        cmd[0] = "jq";
        cmd[1] = "{abi, bytecode: {object: .bytecode.object}, deployedBytecode: {object: .deployedBytecode.object}}";
        cmd[2] = livePath(contractName);
        return vm.ffi(cmd);
    }
}
