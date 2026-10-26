// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {LibEvaluable} from "../../../../src/lib/caller/LibEvaluable.sol";
import {LibEvaluableSlow} from "./LibEvaluableSlow.sol";
import {IInterpreterStoreV3} from "../../../../src/interface/IInterpreterStoreV3.sol";

import {EvaluableV4} from "../../../../src/interface/IInterpreterCallerV5.sol";
import {IInterpreterV4} from "../../../../src/interface/IInterpreterV4.sol";

contract LibEvaluableTest is Test {
    using LibEvaluable for EvaluableV4;

    /// Test a known hash so that if the hash function changes, we know.
    function testEvaluableV4KnownHash() external pure {
        EvaluableV4 memory evaluable =
            EvaluableV4(IInterpreterV4(address(1)), IInterpreterStoreV3(address(2)), hex"030405");
        assertEq(evaluable.hash(), bytes32(0x389371bb1206fa55c5ce170f501ebbe5aacd211e163a6076a349c8bc6437aaa9));
    }

    function testEvaluableV4HashDifferent(EvaluableV4 memory a, EvaluableV4 memory b) public pure {
        vm.assume(
            a.interpreter != b.interpreter || a.store != b.store || keccak256(a.bytecode) != keccak256(b.bytecode)
        );
        assertTrue(a.hash() != b.hash());
    }

    function testEvaluableV4HashSame(EvaluableV4 memory a) public pure {
        EvaluableV4 memory b = EvaluableV4(a.interpreter, a.store, a.bytecode);
        assertEq(a.hash(), b.hash());
    }

    function testEvaluableV4HashSensitivity(EvaluableV4 memory a, EvaluableV4 memory b) public pure {
        vm.assume(
            a.interpreter != b.interpreter && a.store != b.store && keccak256(a.bytecode) != keccak256(b.bytecode)
        );

        EvaluableV4 memory c;

        assertTrue(a.hash() != b.hash());

        // Check interpreter changes hash.
        c = EvaluableV4(b.interpreter, a.store, a.bytecode);
        assertTrue(a.hash() != c.hash());

        // Check store changes hash.
        c = EvaluableV4(a.interpreter, b.store, a.bytecode);
        assertTrue(a.hash() != c.hash());

        // Check bytecode changes hash.
        c = EvaluableV4(a.interpreter, a.store, b.bytecode);
        assertTrue(a.hash() != c.hash());

        // Check match.
        c = EvaluableV4(a.interpreter, a.store, a.bytecode);
        assertEq(a.hash(), c.hash());

        // Check hash doesn't include extraneous data
        uint256 v0 = type(uint256).max;
        uint256 v1 = 0;
        EvaluableV4 memory d = EvaluableV4(IInterpreterV4(address(0)), IInterpreterStoreV3(address(0)), hex"");
        assembly ("memory-safe") {
            mstore(mload(0x40), v0)
        }
        bytes32 hash0 = d.hash();
        assembly ("memory-safe") {
            mstore(mload(0x40), v1)
        }
        bytes32 hash1 = d.hash();
        assertEq(hash0, hash1);
    }

    function testEvaluableV4HashGas0() public pure {
        EvaluableV4(IInterpreterV4(address(0)), IInterpreterStoreV3(address(0)), hex"").hash();
    }

    function testEvaluableV4BytecodeLengthSensitivity() public pure {
        EvaluableV4 memory a = EvaluableV4(IInterpreterV4(address(0)), IInterpreterStoreV3(address(0)), hex"01");
        // `b` is identical to `a` except for the bytecode length.
        // Note the trailing `00` in the bytecode would be the same in memory as
        // the `00` padding that the allocator would add to `a`'s bytecode.
        EvaluableV4 memory b = EvaluableV4(IInterpreterV4(address(0)), IInterpreterStoreV3(address(0)), hex"0100");
        assertTrue(a.hash() != b.hash());
    }

    function testEvaluableV4HashGasSlow0() public pure {
        LibEvaluableSlow.hashSlow(EvaluableV4(IInterpreterV4(address(0)), IInterpreterStoreV3(address(0)), hex""));
    }

    function testEvaluableV4ReferenceImplementation(EvaluableV4 memory evaluable) public pure {
        assertEq(LibEvaluable.hash(evaluable), LibEvaluableSlow.hashSlow(evaluable));
    }
}
