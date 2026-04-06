// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Script} from "forge-std/Script.sol";
import {LibAllStandardOps} from "../src/lib/op/LibAllStandardOps.sol";
import {LibRainlangReferenceExtern} from "../src/concrete/extern/RainlangReferenceExtern.sol";

/// @title BuildAuthoringMeta
/// @notice Forge script that writes raw ABI-encoded AuthoringMeta bytes to
/// disk for each parser. The output files are consumed by the `i9r-prelude`
/// meta build pipeline which deflates and cbor-encodes them.
contract BuildAuthoringMeta is Script {
    /// Writes raw ABI-encoded authoring meta bytes to disk for both the
    /// standard ops and the reference extern. The output files are consumed
    /// by the `i9r-prelude` meta build pipeline to produce the final
    /// deflated/cbor-encoded meta.
    function run() external {
        vm.writeFileBinary("meta/AuthoringMeta.rain.meta", LibAllStandardOps.authoringMetaV2());
        vm.writeFileBinary(
            "meta/RainlangReferenceExternAuthoringMeta.rain.meta", LibRainlangReferenceExtern.authoringMetaV2()
        );
    }
}
