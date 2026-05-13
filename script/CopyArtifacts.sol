// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Script} from "forge-std-1.16.1/src/Script.sol";
import {LibCopyArtifacts} from "./lib/LibCopyArtifacts.sol";

contract CopyArtifacts is Script {
    function run() external {
        string[] memory names = LibCopyArtifacts.contracts();
        for (uint256 i = 0; i < names.length; i++) {
            _copyAbi(names[i]);
        }
    }

    function _copyAbi(string memory contractName) internal {
        bytes memory artifact = LibCopyArtifacts.extractStable(vm, contractName);
        string memory dst = LibCopyArtifacts.committedPath(contractName);
        if (vm.exists(dst)) {
            //forge-lint: disable-next-line(unsafe-cheatcode)
            vm.removeFile(dst);
        }
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeFile(dst, string(artifact));
    }
}
