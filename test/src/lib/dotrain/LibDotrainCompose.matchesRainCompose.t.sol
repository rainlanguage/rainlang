// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {VmSafe} from "forge-std-1.17.0/src/Vm.sol";
import {DotrainComposeCasesTest} from "test/abstract/DotrainComposeCasesTest.sol";
import {LibDotrainCompose} from "../../../../src/lib/dotrain/LibDotrainCompose.sol";
import {DotrainBinding} from "../../../../src/interface/IParserDotrainV1.sol";

/// Oracle: `rain dotrain compose` from the `rain-cli` package of this repo's
/// flake. `compose` must equal its stdout minus the trailing newline.
contract LibDotrainComposeMatchesRainComposeTest is DotrainComposeCasesTest {
    string internal sRain;

    function setUp() external {
        string[] memory cmd = new string[](5);
        cmd[0] = "nix";
        cmd[1] = "build";
        cmd[2] = "--no-link";
        cmd[3] = "--print-out-paths";
        cmd[4] = ".#rain-cli";
        VmSafe.FfiResult memory result = vm.tryFfi(cmd);
        assertEq(result.exitCode, 0, string(result.stderr));
        sRain = string.concat(string(result.stdout), "/bin/rain");
    }

    /// A temp dir per call as fuzz cases run in parallel; hex output so ffi cannot trim it.
    function rainCompose(string memory dotrain, string memory entrypoint, DotrainBinding[] memory bound)
        internal
        returns (string memory)
    {
        string memory command = string.concat(sRain, " dotrain compose -i \"$d/in.rain\" -e ", entrypoint);
        for (uint256 i = 0; i < bound.length; i++) {
            command = string.concat(command, " -b ", bound[i].name, "=", LibDotrainCompose.hexLiteral(bound[i].value));
        }
        string[] memory cmd = new string[](5);
        cmd[0] = "bash";
        cmd[1] = "-c";
        cmd[2] = string.concat(
            "set -e; d=$(mktemp -d); trap 'rm -rf \"$d\"' EXIT; printf %s \"$1\" > \"$d/in.rain\"; ",
            command,
            " > \"$d/out.rl\"; printf 0x; od -An -v -tx1 \"$d/out.rl\" | tr -d ' \\n'"
        );
        cmd[3] = "rain-compose";
        cmd[4] = dotrain;
        VmSafe.FfiResult memory result = vm.tryFfi(cmd);
        assertEq(result.exitCode, 0, string.concat(dotrain, "\n", string(result.stderr)));
        return string(result.stdout);
    }

    function checkCase(string memory dotrain, string memory entrypoint, DotrainBinding[] memory bound)
        internal
        override
    {
        string memory expected = rainCompose(dotrain, entrypoint, bound);
        assertEq(string.concat(LibDotrainCompose.compose(dotrain, entrypoint, bound), "\n"), expected, dotrain);
    }
}
