// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {TestRainlangParser} from "../../concrete/TestRainlangParser.sol";
import {TestRainlangStore} from "../../concrete/TestRainlangStore.sol";
import {TestRainlangInterpreter} from "../../concrete/TestRainlangInterpreter.sol";
import {TestRainlangCompiler} from "../../concrete/TestRainlangCompiler.sol";
import {TestRainlang} from "../../concrete/TestRainlang.sol";

/// @dev Where `LibTestInterpreterDeploy.etchTestRainlang` places the parser.
address constant TEST_PARSER_ADDRESS = address(uint160(uint256(keccak256("rainlang.test.parser"))));
/// @dev Where `LibTestInterpreterDeploy.etchTestRainlang` places the store.
address constant TEST_STORE_ADDRESS = address(uint160(uint256(keccak256("rainlang.test.store"))));
/// @dev Where `LibTestInterpreterDeploy.etchTestRainlang` places the
/// interpreter.
address constant TEST_INTERPRETER_ADDRESS = address(uint160(uint256(keccak256("rainlang.test.interpreter"))));
/// @dev Where `LibTestInterpreterDeploy.etchTestRainlang` places the expression
/// compiler.
address constant TEST_COMPILER_ADDRESS = address(uint160(uint256(keccak256("rainlang.test.compiler"))));
/// @dev Where `LibTestInterpreterDeploy.etchTestRainlang` places `TestRainlang`.
address constant TEST_RAINLANG_ADDRESS = address(uint160(uint256(keccak256("rainlang.test.rainlang"))));

/// Thrown when a test contract's constructor reverts while being etched.
/// @param target The address the contract was being placed at.
error TestDeployFailed(address target);

/// @title LibTestInterpreterDeploy
/// @notice Places the test concretes, built from this repo's source with no
/// generated tables, at fixed addresses so tests of the library logic run
/// against the current source rather than a deploy record.
library LibTestInterpreterDeploy {
    /// Runs `creationCode` as `target` so its constructor's storage writes
    /// land there, then leaves the runtime code it returned.
    function deployTo(Vm vm, address target, bytes memory creationCode) internal {
        vm.etch(target, creationCode);
        //slither-disable-next-line low-level-calls
        (bool success, bytes memory runtimeCode) = target.call("");
        if (!success) revert TestDeployFailed(target);
        vm.etch(target, runtimeCode);
    }

    /// Places all five test concretes at their `TEST_*_ADDRESS`.
    function etchTestRainlang(Vm vm) internal {
        deployTo(vm, TEST_PARSER_ADDRESS, type(TestRainlangParser).creationCode);
        deployTo(vm, TEST_STORE_ADDRESS, type(TestRainlangStore).creationCode);
        deployTo(vm, TEST_INTERPRETER_ADDRESS, type(TestRainlangInterpreter).creationCode);
        deployTo(vm, TEST_COMPILER_ADDRESS, type(TestRainlangCompiler).creationCode);
        deployTo(vm, TEST_RAINLANG_ADDRESS, type(TestRainlang).creationCode);
    }
}
