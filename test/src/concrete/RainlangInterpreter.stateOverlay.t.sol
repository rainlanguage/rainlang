// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    RainlangExpressionDeployerDeploymentTest
} from "test/abstract/RainlangExpressionDeployerDeploymentTest.sol";
import {StateNamespace} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";
import {EvalV4, SourceIndexV2, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibNamespace} from "rain.interpreter.interface/lib/ns/LibNamespace.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";
import {OddSetLength} from "../../../src/error/ErrStore.sol";

contract RainlangInterpreterStateOverlayTest is RainlangExpressionDeployerDeploymentTest {
    /// Odd-length stateOverlay MUST revert with OddSetLength.
    function testStateOverlayOddLength(bytes32[] memory stateOverlay) external {
        vm.assume(stateOverlay.length % 2 != 0);

        bytes memory bytecode = I_DEPLOYER.parse2("_: 1;");

        vm.expectRevert(abi.encodeWithSelector(OddSetLength.selector, stateOverlay.length));
        I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: LibNamespace.qualifyNamespace(StateNamespace.wrap(0), address(this)),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: new bytes32[][](0),
                inputs: new StackItem[](0),
                stateOverlay: stateOverlay
            })
        );
    }

    /// Show that state overlay can prewarm a get.
    function testStateOverlayGet() external view {
        bytes memory bytecode = I_DEPLOYER.parse2("_: get(9);");

        bytes32 k = Float.unwrap(LibDecimalFloat.packLossless(9, 0));
        bytes32 v = bytes32(uint256(42));
        bytes32[] memory stateOverlay = new bytes32[](2);
        stateOverlay[0] = k;
        stateOverlay[1] = v;

        (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: LibNamespace.qualifyNamespace(StateNamespace.wrap(0), address(this)),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: new bytes32[][](0),
                inputs: new StackItem[](0),
                stateOverlay: stateOverlay
            })
        );

        assertEq(stack.length, 1);
        assertEq(StackItem.unwrap(stack[0]), v);
        assertEq(kvs.length, 2);
        assertEq(kvs[0], k);
        assertEq(kvs[1], v);
    }

    /// @notice stateOverlay with two key-value pairs MUST apply both to the
    /// state KV. Both keys should be readable via `get` in the evaluated source.
    function testStateOverlayMultiplePairs() external view {
        bytes memory bytecode = I_DEPLOYER.parse2("a b: get(1) get(2);");

        bytes32 k1 = Float.unwrap(LibDecimalFloat.packLossless(1, 0));
        bytes32 v1 = bytes32(uint256(100));
        bytes32 k2 = Float.unwrap(LibDecimalFloat.packLossless(2, 0));
        bytes32 v2 = bytes32(uint256(200));

        bytes32[] memory stateOverlay = new bytes32[](4);
        stateOverlay[0] = k1;
        stateOverlay[1] = v1;
        stateOverlay[2] = k2;
        stateOverlay[3] = v2;

        (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: LibNamespace.qualifyNamespace(StateNamespace.wrap(0), address(this)),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: new bytes32[][](0),
                inputs: new StackItem[](0),
                stateOverlay: stateOverlay
            })
        );

        assertEq(stack.length, 2, "two get ops should produce two stack items");
        assertEq(StackItem.unwrap(stack[0]), v2, "get(2) should return v2");
        assertEq(StackItem.unwrap(stack[1]), v1, "get(1) should return v1");
        assertEq(kvs.length, 4, "kvs should contain two key-value pairs");
    }

    /// @notice stateOverlay with three key-value pairs MUST apply all three.
    function testStateOverlayThreePairs() external view {
        bytes memory bytecode = I_DEPLOYER.parse2("a b c: get(1) get(2) get(3);");

        bytes32 k1 = Float.unwrap(LibDecimalFloat.packLossless(1, 0));
        bytes32 v1 = bytes32(uint256(10));
        bytes32 k2 = Float.unwrap(LibDecimalFloat.packLossless(2, 0));
        bytes32 v2 = bytes32(uint256(20));
        bytes32 k3 = Float.unwrap(LibDecimalFloat.packLossless(3, 0));
        bytes32 v3 = bytes32(uint256(30));

        bytes32[] memory stateOverlay = new bytes32[](6);
        stateOverlay[0] = k1;
        stateOverlay[1] = v1;
        stateOverlay[2] = k2;
        stateOverlay[3] = v2;
        stateOverlay[4] = k3;
        stateOverlay[5] = v3;

        (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: LibNamespace.qualifyNamespace(StateNamespace.wrap(0), address(this)),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: new bytes32[][](0),
                inputs: new StackItem[](0),
                stateOverlay: stateOverlay
            })
        );

        assertEq(stack.length, 3, "three get ops should produce three stack items");
        assertEq(StackItem.unwrap(stack[0]), v3, "get(3) should return v3");
        assertEq(StackItem.unwrap(stack[1]), v2, "get(2) should return v2");
        assertEq(StackItem.unwrap(stack[2]), v1, "get(1) should return v1");
        assertEq(kvs.length, 6, "kvs should contain three key-value pairs");
    }

    /// @notice When stateOverlay contains the same key twice, the LAST value
    /// for that key MUST win (last-write-wins semantics from sequential `set`
    /// calls).
    function testStateOverlayDuplicateKeyLastWins() external view {
        bytes memory bytecode = I_DEPLOYER.parse2("_: get(5);");

        bytes32 k = Float.unwrap(LibDecimalFloat.packLossless(5, 0));
        bytes32 v1 = bytes32(uint256(111));
        bytes32 v2 = bytes32(uint256(222));

        bytes32[] memory stateOverlay = new bytes32[](4);
        stateOverlay[0] = k;
        stateOverlay[1] = v1;
        stateOverlay[2] = k;
        stateOverlay[3] = v2;

        (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: LibNamespace.qualifyNamespace(StateNamespace.wrap(0), address(this)),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: new bytes32[][](0),
                inputs: new StackItem[](0),
                stateOverlay: stateOverlay
            })
        );

        assertEq(stack.length, 1, "single get should produce one stack item");
        assertEq(StackItem.unwrap(stack[0]), v2, "duplicate key in overlay: last value should win");
        assertEq(kvs.length, 2, "kvs should contain one key-value pair (deduplicated)");
        assertEq(kvs[0], k, "kvs key should be the overlay key");
        assertEq(kvs[1], v2, "kvs value should be the last-written value");
    }

    /// @notice When stateOverlay has duplicate keys interleaved with other
    /// keys, each duplicate key's last value MUST win independently.
    function testStateOverlayDuplicateKeysInterleaved() external view {
        bytes memory bytecode = I_DEPLOYER.parse2("a b: get(1) get(2);");

        bytes32 k1 = Float.unwrap(LibDecimalFloat.packLossless(1, 0));
        bytes32 k2 = Float.unwrap(LibDecimalFloat.packLossless(2, 0));
        bytes32 v1First = bytes32(uint256(10));
        bytes32 v2First = bytes32(uint256(20));
        bytes32 v1Second = bytes32(uint256(11));
        bytes32 v2Second = bytes32(uint256(22));

        bytes32[] memory stateOverlay = new bytes32[](8);
        stateOverlay[0] = k1;
        stateOverlay[1] = v1First;
        stateOverlay[2] = k2;
        stateOverlay[3] = v2First;
        stateOverlay[4] = k1;
        stateOverlay[5] = v1Second;
        stateOverlay[6] = k2;
        stateOverlay[7] = v2Second;

        (StackItem[] memory stack,) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: LibNamespace.qualifyNamespace(StateNamespace.wrap(0), address(this)),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: new bytes32[][](0),
                inputs: new StackItem[](0),
                stateOverlay: stateOverlay
            })
        );

        assertEq(stack.length, 2, "two get ops should produce two stack items");
        assertEq(StackItem.unwrap(stack[0]), v2Second, "get(2) should return the second value for k2");
        assertEq(StackItem.unwrap(stack[1]), v1Second, "get(1) should return the second value for k1");
    }

    /// Show that state overlay can be overridden by a set in the bytecode.
    function testStateOverlaySet() external view {
        bytes memory bytecode = I_DEPLOYER.parse2("_:get(9),:set(9 42),_:get(9);");

        bytes32 k = Float.unwrap(LibDecimalFloat.packLossless(9, 0));
        bytes32 v = Float.unwrap(LibDecimalFloat.packLossless(43, 0));
        bytes32[] memory stateOverlay = new bytes32[](2);
        stateOverlay[0] = k;
        stateOverlay[1] = v;

        (StackItem[] memory stack, bytes32[] memory kvs) = I_INTERPRETER.eval4(
            EvalV4({
                store: I_STORE,
                namespace: LibNamespace.qualifyNamespace(StateNamespace.wrap(0), address(this)),
                bytecode: bytecode,
                sourceIndex: SourceIndexV2.wrap(0),
                context: new bytes32[][](0),
                inputs: new StackItem[](0),
                stateOverlay: stateOverlay
            })
        );

        bytes32 setTo = Float.unwrap(LibDecimalFloat.packLossless(42, 0));

        assertEq(stack.length, 2);
        assertEq(StackItem.unwrap(stack[0]), setTo);
        assertEq(StackItem.unwrap(stack[1]), v);
        assertEq(kvs.length, 2);
        assertEq(kvs[0], k);
        assertEq(kvs[1], setTo);
    }
}
