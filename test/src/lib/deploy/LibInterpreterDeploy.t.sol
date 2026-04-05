// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {LibRainDeploy} from "rain.deploy/lib/LibRainDeploy.sol";
import {LibInterpreterDeploy} from "../../../../src/lib/deploy/LibInterpreterDeploy.sol";
import {RainlangParser} from "../../../../src/concrete/RainlangParser.sol";
import {RainlangStore} from "../../../../src/concrete/RainlangStore.sol";
import {RainlangInterpreter} from "../../../../src/concrete/RainlangInterpreter.sol";
import {RainlangExpressionDeployer} from "../../../../src/concrete/RainlangExpressionDeployer.sol";
import {Rainlang} from "../../../../src/concrete/Rainlang.sol";
import {LibExtrospectBytecode} from "rain.extrospection/lib/LibExtrospectBytecode.sol";
import {LibExtrospectMetamorphic} from "rain.extrospection/lib/LibExtrospectMetamorphic.sol";
import {RainlangReferenceExtern} from "../../../../src/concrete/extern/RainlangReferenceExtern.sol";
import {
    CREATION_CODE as PARSER_CREATION_CODE,
    RUNTIME_CODE as PARSER_RUNTIME_CODE,
    DEPLOYED_ADDRESS as PARSER_GENERATED_ADDRESS
} from "../../../../src/generated/RainlangParser.pointers.sol";
import {
    CREATION_CODE as STORE_CREATION_CODE,
    RUNTIME_CODE as STORE_RUNTIME_CODE,
    DEPLOYED_ADDRESS as STORE_GENERATED_ADDRESS
} from "../../../../src/generated/RainlangStore.pointers.sol";
import {
    CREATION_CODE as INTERPRETER_CREATION_CODE,
    RUNTIME_CODE as INTERPRETER_RUNTIME_CODE,
    DEPLOYED_ADDRESS as INTERPRETER_GENERATED_ADDRESS
} from "../../../../src/generated/RainlangInterpreter.pointers.sol";
import {
    CREATION_CODE as EXPRESSION_DEPLOYER_CREATION_CODE,
    RUNTIME_CODE as EXPRESSION_DEPLOYER_RUNTIME_CODE,
    DEPLOYED_ADDRESS as EXPRESSION_DEPLOYER_GENERATED_ADDRESS
} from "../../../../src/generated/RainlangExpressionDeployer.pointers.sol";
import {
    CREATION_CODE as RAINLANG_CREATION_CODE,
    RUNTIME_CODE as RAINLANG_RUNTIME_CODE,
    DEPLOYED_ADDRESS as RAINLANG_GENERATED_ADDRESS
} from "../../../../src/generated/Rainlang.pointers.sol";
import {
    CREATION_CODE as REFERENCE_EXTERN_CREATION_CODE,
    RUNTIME_CODE as REFERENCE_EXTERN_RUNTIME_CODE
} from "../../../../src/generated/RainlangReferenceExtern.pointers.sol";

contract LibInterpreterDeployTest is Test {
    function testDeployAddressParser() external {
        vm.createSelectFork(vm.envString("CI_FORK_ETH_RPC_URL"));

        console2.logBytes(LibRainDeploy.ZOLTU_FACTORY.code);

        address deployedAddress = LibRainDeploy.deployZoltu(type(RainlangParser).creationCode);

        assertEq(deployedAddress, LibInterpreterDeploy.PARSER_DEPLOYED_ADDRESS);
        assertTrue(address(deployedAddress).code.length > 0, "Deployed address has no code");

        assertEq(address(deployedAddress).codehash, LibInterpreterDeploy.PARSER_DEPLOYED_CODEHASH);
    }

    function testExpectedCodeHashParser() external {
        RainlangParser parser = new RainlangParser();

        assertEq(address(parser).codehash, LibInterpreterDeploy.PARSER_DEPLOYED_CODEHASH);
    }

    function testDeployAddressStore() external {
        vm.createSelectFork(vm.envString("CI_FORK_ETH_RPC_URL"));

        address deployedAddress = LibRainDeploy.deployZoltu(type(RainlangStore).creationCode);

        assertEq(deployedAddress, LibInterpreterDeploy.STORE_DEPLOYED_ADDRESS);
        assertTrue(address(deployedAddress).code.length > 0, "Deployed address has no code");

        assertEq(address(deployedAddress).codehash, LibInterpreterDeploy.STORE_DEPLOYED_CODEHASH);
    }

    function testExpectedCodeHashStore() external {
        RainlangStore store = new RainlangStore();

        assertEq(address(store).codehash, LibInterpreterDeploy.STORE_DEPLOYED_CODEHASH);
    }

    function testDeployAddressInterpreter() external {
        vm.createSelectFork(vm.envString("CI_FORK_ETH_RPC_URL"));

        address deployedAddress = LibRainDeploy.deployZoltu(type(RainlangInterpreter).creationCode);

        assertEq(deployedAddress, LibInterpreterDeploy.INTERPRETER_DEPLOYED_ADDRESS);
        assertTrue(address(deployedAddress).code.length > 0, "Deployed address has no code");

        assertEq(address(deployedAddress).codehash, LibInterpreterDeploy.INTERPRETER_DEPLOYED_CODEHASH);
    }

    function testExpectedCodeHashInterpreter() external {
        RainlangInterpreter interpreter = new RainlangInterpreter();

        assertEq(address(interpreter).codehash, LibInterpreterDeploy.INTERPRETER_DEPLOYED_CODEHASH);
    }

    function testDeployAddressExpressionDeployer() external {
        vm.createSelectFork(vm.envString("CI_FORK_ETH_RPC_URL"));

        address deployedAddress = LibRainDeploy.deployZoltu(type(RainlangExpressionDeployer).creationCode);

        console2.log("Deployed address:", deployedAddress);

        assertEq(deployedAddress, LibInterpreterDeploy.EXPRESSION_DEPLOYER_DEPLOYED_ADDRESS);
        assertTrue(address(deployedAddress).code.length > 0, "Deployed address has no code");

        assertEq(address(deployedAddress).codehash, LibInterpreterDeploy.EXPRESSION_DEPLOYER_DEPLOYED_CODEHASH);
    }

    function testExpectedCodeHashExpressionDeployer() external {
        RainlangExpressionDeployer expressionDeployer = new RainlangExpressionDeployer();

        assertEq(address(expressionDeployer).codehash, LibInterpreterDeploy.EXPRESSION_DEPLOYER_DEPLOYED_CODEHASH);
    }

    function testDeployAddressRainlang() external {
        vm.createSelectFork(vm.envString("CI_FORK_ETH_RPC_URL"));

        address deployedAddress = LibRainDeploy.deployZoltu(type(Rainlang).creationCode);

        assertEq(deployedAddress, LibInterpreterDeploy.RAINLANG_DEPLOYED_ADDRESS);
        assertTrue(address(deployedAddress).code.length > 0, "Deployed address has no code");

        assertEq(address(deployedAddress).codehash, LibInterpreterDeploy.RAINLANG_DEPLOYED_CODEHASH);
    }

    function testExpectedCodeHashRainlang() external {
        Rainlang rainlang = new Rainlang();

        assertEq(address(rainlang).codehash, LibInterpreterDeploy.RAINLANG_DEPLOYED_CODEHASH);
    }

    /// Parser bytecode MUST NOT contain Solidity CBOR metadata.
    function testNoCborMetadataParser() external {
        RainlangParser parser = new RainlangParser();
        assertFalse(
            LibExtrospectBytecode.tryTrimSolidityCBORMetadata(address(parser).code),
            "Parser bytecode contains CBOR metadata"
        );
    }

    /// Store bytecode MUST NOT contain Solidity CBOR metadata.
    function testNoCborMetadataStore() external {
        RainlangStore store = new RainlangStore();
        assertFalse(
            LibExtrospectBytecode.tryTrimSolidityCBORMetadata(address(store).code),
            "Store bytecode contains CBOR metadata"
        );
    }

    /// Interpreter bytecode MUST NOT contain Solidity CBOR metadata.
    function testNoCborMetadataInterpreter() external {
        RainlangInterpreter interpreter = new RainlangInterpreter();
        assertFalse(
            LibExtrospectBytecode.tryTrimSolidityCBORMetadata(address(interpreter).code),
            "Interpreter bytecode contains CBOR metadata"
        );
    }

    /// ExpressionDeployer bytecode MUST NOT contain Solidity CBOR metadata.
    function testNoCborMetadataExpressionDeployer() external {
        RainlangExpressionDeployer expressionDeployer = new RainlangExpressionDeployer();
        assertFalse(
            LibExtrospectBytecode.tryTrimSolidityCBORMetadata(address(expressionDeployer).code),
            "ExpressionDeployer bytecode contains CBOR metadata"
        );
    }

    /// Rainlang bytecode MUST NOT contain Solidity CBOR metadata.
    function testNoCborMetadataRainlang() external {
        Rainlang rainlang = new Rainlang();
        assertFalse(
            LibExtrospectBytecode.tryTrimSolidityCBORMetadata(address(rainlang).code),
            "Rainlang bytecode contains CBOR metadata"
        );
    }

    /// Parser bytecode MUST NOT contain reachable metamorphic risk opcodes.
    function testNotMetamorphicParser() external {
        RainlangParser parser = new RainlangParser();
        LibExtrospectMetamorphic.checkNotMetamorphic(address(parser).code);
    }

    /// Store bytecode MUST NOT contain reachable metamorphic risk opcodes.
    function testNotMetamorphicStore() external {
        RainlangStore store = new RainlangStore();
        LibExtrospectMetamorphic.checkNotMetamorphic(address(store).code);
    }

    /// Interpreter bytecode MUST NOT contain reachable metamorphic risk opcodes.
    function testNotMetamorphicInterpreter() external {
        RainlangInterpreter interpreter = new RainlangInterpreter();
        LibExtrospectMetamorphic.checkNotMetamorphic(address(interpreter).code);
    }

    /// ExpressionDeployer bytecode MUST NOT contain reachable metamorphic risk
    /// opcodes.
    function testNotMetamorphicExpressionDeployer() external {
        RainlangExpressionDeployer expressionDeployer = new RainlangExpressionDeployer();
        LibExtrospectMetamorphic.checkNotMetamorphic(address(expressionDeployer).code);
    }

    /// Rainlang bytecode MUST NOT contain reachable metamorphic risk opcodes.
    function testNotMetamorphicRainlang() external {
        Rainlang rainlang = new Rainlang();
        LibExtrospectMetamorphic.checkNotMetamorphic(address(rainlang).code);
    }

    /// The precompiled creation code constant for the parser MUST match the
    /// compiler's creation code.
    function testCreationCodeParser() external pure {
        assertEq(keccak256(PARSER_CREATION_CODE), keccak256(type(RainlangParser).creationCode));
    }

    /// The precompiled creation code constant for the store MUST match the
    /// compiler's creation code.
    function testCreationCodeStore() external pure {
        assertEq(keccak256(STORE_CREATION_CODE), keccak256(type(RainlangStore).creationCode));
    }

    /// The precompiled creation code constant for the interpreter MUST match
    /// the compiler's creation code.
    function testCreationCodeInterpreter() external pure {
        assertEq(keccak256(INTERPRETER_CREATION_CODE), keccak256(type(RainlangInterpreter).creationCode));
    }

    /// The precompiled creation code constant for the expression deployer MUST
    /// match the compiler's creation code.
    function testCreationCodeExpressionDeployer() external pure {
        assertEq(
            keccak256(EXPRESSION_DEPLOYER_CREATION_CODE), keccak256(type(RainlangExpressionDeployer).creationCode)
        );
    }

    /// The precompiled creation code constant for Rainlang MUST match the
    /// compiler's creation code.
    function testCreationCodeRainlang() external pure {
        assertEq(keccak256(RAINLANG_CREATION_CODE), keccak256(type(Rainlang).creationCode));
    }

    /// The precompiled creation code constant for the reference extern MUST
    /// match the compiler's creation code.
    function testCreationCodeReferenceExtern() external pure {
        assertEq(keccak256(REFERENCE_EXTERN_CREATION_CODE), keccak256(type(RainlangReferenceExtern).creationCode));
    }

    /// The precompiled runtime code constant for the parser MUST match the
    /// deployed runtime bytecode.
    function testRuntimeCodeParser() external {
        RainlangParser parser = new RainlangParser();
        assertEq(keccak256(PARSER_RUNTIME_CODE), keccak256(address(parser).code));
    }

    /// The precompiled runtime code constant for the store MUST match the
    /// deployed runtime bytecode.
    function testRuntimeCodeStore() external {
        RainlangStore store = new RainlangStore();
        assertEq(keccak256(STORE_RUNTIME_CODE), keccak256(address(store).code));
    }

    /// The precompiled runtime code constant for the interpreter MUST match
    /// the deployed runtime bytecode.
    function testRuntimeCodeInterpreter() external {
        RainlangInterpreter interpreter = new RainlangInterpreter();
        assertEq(keccak256(INTERPRETER_RUNTIME_CODE), keccak256(address(interpreter).code));
    }

    /// The precompiled runtime code constant for the expression deployer MUST
    /// match the deployed runtime bytecode.
    function testRuntimeCodeExpressionDeployer() external {
        RainlangExpressionDeployer deployer = new RainlangExpressionDeployer();
        assertEq(keccak256(EXPRESSION_DEPLOYER_RUNTIME_CODE), keccak256(address(deployer).code));
    }

    /// The precompiled runtime code constant for Rainlang MUST match the
    /// deployed runtime bytecode.
    function testRuntimeCodeRainlang() external {
        Rainlang rainlang = new Rainlang();
        assertEq(keccak256(RAINLANG_RUNTIME_CODE), keccak256(address(rainlang).code));
    }

    /// The precompiled runtime code constant for the reference extern MUST
    /// match the deployed runtime bytecode.
    function testRuntimeCodeReferenceExtern() external {
        RainlangReferenceExtern extern = new RainlangReferenceExtern();
        assertEq(keccak256(REFERENCE_EXTERN_RUNTIME_CODE), keccak256(address(extern).code));
    }

    /// The generated deployed address for the parser MUST match the deploy
    /// library constant.
    function testGeneratedDeployedAddressParser() external pure {
        assertEq(PARSER_GENERATED_ADDRESS, LibInterpreterDeploy.PARSER_DEPLOYED_ADDRESS);
    }

    /// The generated deployed address for the store MUST match the deploy
    /// library constant.
    function testGeneratedDeployedAddressStore() external pure {
        assertEq(STORE_GENERATED_ADDRESS, LibInterpreterDeploy.STORE_DEPLOYED_ADDRESS);
    }

    /// The generated deployed address for the interpreter MUST match the
    /// deploy library constant.
    function testGeneratedDeployedAddressInterpreter() external pure {
        assertEq(INTERPRETER_GENERATED_ADDRESS, LibInterpreterDeploy.INTERPRETER_DEPLOYED_ADDRESS);
    }

    /// The generated deployed address for the expression deployer MUST match
    /// the deploy library constant.
    function testGeneratedDeployedAddressExpressionDeployer() external pure {
        assertEq(EXPRESSION_DEPLOYER_GENERATED_ADDRESS, LibInterpreterDeploy.EXPRESSION_DEPLOYER_DEPLOYED_ADDRESS);
    }

    /// The generated deployed address for Rainlang MUST match the deploy
    /// library constant.
    function testGeneratedDeployedAddressRainlang() external pure {
        assertEq(RAINLANG_GENERATED_ADDRESS, LibInterpreterDeploy.RAINLANG_DEPLOYED_ADDRESS);
    }

    /// After calling etchRainlang, all five contracts MUST have the expected
    /// codehash at their expected addresses.
    function testEtchRainlang() external {
        LibInterpreterDeploy.etchRainlang(vm);

        assertEq(LibInterpreterDeploy.PARSER_DEPLOYED_ADDRESS.codehash, LibInterpreterDeploy.PARSER_DEPLOYED_CODEHASH);
        assertEq(LibInterpreterDeploy.STORE_DEPLOYED_ADDRESS.codehash, LibInterpreterDeploy.STORE_DEPLOYED_CODEHASH);
        assertEq(
            LibInterpreterDeploy.INTERPRETER_DEPLOYED_ADDRESS.codehash,
            LibInterpreterDeploy.INTERPRETER_DEPLOYED_CODEHASH
        );
        assertEq(
            LibInterpreterDeploy.EXPRESSION_DEPLOYER_DEPLOYED_ADDRESS.codehash,
            LibInterpreterDeploy.EXPRESSION_DEPLOYER_DEPLOYED_CODEHASH
        );
        assertEq(
            LibInterpreterDeploy.RAINLANG_DEPLOYED_ADDRESS.codehash, LibInterpreterDeploy.RAINLANG_DEPLOYED_CODEHASH
        );
    }

    /// Calling etchRainlang twice MUST be idempotent — codehashes remain
    /// correct on the second call.
    function testEtchRainlangIdempotent() external {
        LibInterpreterDeploy.etchRainlang(vm);
        LibInterpreterDeploy.etchRainlang(vm);

        assertEq(LibInterpreterDeploy.PARSER_DEPLOYED_ADDRESS.codehash, LibInterpreterDeploy.PARSER_DEPLOYED_CODEHASH);
        assertEq(LibInterpreterDeploy.STORE_DEPLOYED_ADDRESS.codehash, LibInterpreterDeploy.STORE_DEPLOYED_CODEHASH);
        assertEq(
            LibInterpreterDeploy.INTERPRETER_DEPLOYED_ADDRESS.codehash,
            LibInterpreterDeploy.INTERPRETER_DEPLOYED_CODEHASH
        );
        assertEq(
            LibInterpreterDeploy.EXPRESSION_DEPLOYER_DEPLOYED_ADDRESS.codehash,
            LibInterpreterDeploy.EXPRESSION_DEPLOYER_DEPLOYED_CODEHASH
        );
        assertEq(
            LibInterpreterDeploy.RAINLANG_DEPLOYED_ADDRESS.codehash, LibInterpreterDeploy.RAINLANG_DEPLOYED_CODEHASH
        );
    }
}
