// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {
    LibContext,
    MessageHashUtils,
    CONTEXT_BASE_COLUMN,
    CONTEXT_BASE_ROWS
} from "../../../../src/lib/caller/LibContext.sol";
import {SignedContextV2} from "../../../../src/interface/IInterpreterCallerV5.sol";

/// Values come from viem 2.57.11 `signTypedData`, `hashTypedData`,
/// `hashStruct` and `hashDomain` with anvil key 0.
contract LibContextKnownGoodVectorTest is Test {
    address constant SIGNER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address constant VERIFYING_CONTRACT = 0x1234567890123456789012345678901234567890;
    bytes32 constant STRUCT_HASH = 0x64bbb2a3c6e584334ddc8ba4273a69939f4bdff236bb65f8a637e6f87b62ae3c;
    bytes32 constant DOMAIN_SEPARATOR = 0xf3828eb661ffaaeb14b337de7fbf52cd977ec1e4a5657e9e0e42b9d71b272610;
    bytes32 constant DIGEST = 0x8a845f2bcc79b52960694aae02cff6d120f23475adecc8249a35070028e87431;
    bytes constant SIGNATURE =
        hex"b0ea782b9e55ab432cd3c0edf0dfee5514d240b378ed0f52293b085d9ca5e69c44ac96b08c016612ef87f98836b56bbf4f2ef8d1fae1c40a14d17c575e8827711b";

    function buildV2External(bytes32[][] memory baseContext, SignedContextV2[] memory signedContexts)
        external
        view
        returns (bytes32[][] memory)
    {
        return LibContext.buildV2(baseContext, signedContexts);
    }

    function context() internal pure returns (bytes32[] memory) {
        bytes32[] memory words = new bytes32[](3);
        words[0] = bytes32(uint256(1));
        words[1] = 0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef;
        words[2] = bytes32(0);
        return words;
    }

    function testKnownGoodDomainSeparator() external pure {
        string memory name = "LibContextKnownGoodVectorTest";
        string memory version = "1";
        assertEq(
            MessageHashUtils.toDomainSeparator(bytes1(0x0f), name, version, 1, VERIFYING_CONTRACT, 0), DOMAIN_SEPARATOR
        );
    }

    function testKnownGoodHashStruct() external pure {
        assertEq(LibContext.hashStruct(SignedContextV2(SIGNER, DOMAIN_SEPARATOR, context(), SIGNATURE)), STRUCT_HASH);
    }

    function testKnownGoodDigest() external pure {
        assertEq(
            MessageHashUtils.toTypedDataHash(
                DOMAIN_SEPARATOR, LibContext.hashStruct(SignedContextV2(SIGNER, DOMAIN_SEPARATOR, context(), SIGNATURE))
            ),
            DIGEST
        );
    }

    function testKnownGoodBuildV2AcceptsSignature() external view {
        SignedContextV2[] memory signedContexts = new SignedContextV2[](1);
        signedContexts[0] = SignedContextV2(SIGNER, DOMAIN_SEPARATOR, context(), SIGNATURE);

        bytes32[][] memory built = this.buildV2External(new bytes32[][](0), signedContexts);

        assertEq(built.length, 4);
        assertEq(built[CONTEXT_BASE_COLUMN].length, CONTEXT_BASE_ROWS);
        assertEq(built[1].length, 1);
        assertEq(built[1][0], bytes32(uint256(uint160(SIGNER))));
        assertEq(built[2].length, 1);
        assertEq(built[2][0], DOMAIN_SEPARATOR);
        assertEq(built[3], context());
    }
}
