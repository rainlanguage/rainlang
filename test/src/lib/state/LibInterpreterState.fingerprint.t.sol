// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {InterpreterState} from "../../../../src/lib/state/LibInterpreterState.sol";
import {LibInterpreterStateFingerprint} from "test/lib/state/LibInterpreterStateFingerprint.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {MemoryKV} from "rain.lib.memkv/lib/LibMemoryKV.sol";
import {
    FullyQualifiedNamespace,
    IInterpreterStoreV3
} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";

contract LibInterpreterStateFingerprintTest is Test {
    /// Two identically constructed states must produce the same fingerprint.
    function testFingerprintDeterministic() external pure {
        InterpreterState memory a = InterpreterState(
            new Pointer[](0),
            new bytes32[](0),
            0,
            MemoryKV.wrap(0),
            FullyQualifiedNamespace.wrap(0),
            IInterpreterStoreV3(address(0)),
            new bytes32[][](0),
            hex"00",
            hex""
        );
        InterpreterState memory b = InterpreterState(
            new Pointer[](0),
            new bytes32[](0),
            0,
            MemoryKV.wrap(0),
            FullyQualifiedNamespace.wrap(0),
            IInterpreterStoreV3(address(0)),
            new bytes32[][](0),
            hex"00",
            hex""
        );
        assertEq(LibInterpreterStateFingerprint.fingerprint(a), LibInterpreterStateFingerprint.fingerprint(b));
    }

    /// Changing sourceIndex must change the fingerprint.
    function testFingerprintChangesWithSourceIndex(uint256 indexA, uint256 indexB) external pure {
        vm.assume(indexA != indexB);
        InterpreterState memory a = InterpreterState(
            new Pointer[](0),
            new bytes32[](0),
            indexA,
            MemoryKV.wrap(0),
            FullyQualifiedNamespace.wrap(0),
            IInterpreterStoreV3(address(0)),
            new bytes32[][](0),
            hex"00",
            hex""
        );
        InterpreterState memory b = InterpreterState(
            new Pointer[](0),
            new bytes32[](0),
            indexB,
            MemoryKV.wrap(0),
            FullyQualifiedNamespace.wrap(0),
            IInterpreterStoreV3(address(0)),
            new bytes32[][](0),
            hex"00",
            hex""
        );
        assertTrue(LibInterpreterStateFingerprint.fingerprint(a) != LibInterpreterStateFingerprint.fingerprint(b));
    }
}
