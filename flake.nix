{
  description = "Flake for development workflows.";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    rainix.url = "github:rainlanguage/rainix";
    rain.url = "github:rainlanguage/rain.cli";
  };

  outputs =
    {
      flake-utils,
      rainix,
      rain,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = rainix.pkgs.${system};
      in
      rec {
        packages = rec {
          i9r-prelude = rainix.mkTask.${system} {
            name = "i9r-prelude";
            body = ''
              set -euxo pipefail

              # Needed by deploy script.
              mkdir -p deployments/latest;

              # Build metadata that is needed for deployments.
              mkdir -p meta;
              forge script --silent ./script/BuildAuthoringMeta.sol;
              rain meta build \
                -i <(cat ./meta/AuthoringMeta.rain.meta) \
                -m authoring-meta-v2 \
                -t cbor \
                -e deflate \
                -l none \
                -o meta/RainlangExpressionDeployer.rain.meta \
              ;

              rain meta build \
                -i <(cat ./meta/RainlangReferenceExternAuthoringMeta.rain.meta) \
                -m authoring-meta-v2 \
                -t cbor \
                -e deflate \
                -l none \
                -o meta/RainlangReferenceExtern.rain.meta \
            '';
            additionalBuildInputs = rainix.sol-build-inputs.${system} ++ [ rain.defaultPackage.${system} ];
          };

          test-wasm-build = rainix.mkTask.${system} {
            name = "test-wasm-build";
            body = ''
              set -euxo pipefail

              cargo build --target wasm32-unknown-unknown --exclude rain-i9r-cli --workspace
            '';
          };
        }
        // rainix.packages.${system};

        devShells.default = pkgs.mkShell {
          inherit (rainix.devShells.${system}.default) shellHook;
          packages = [
            packages.i9r-prelude
            packages.test-wasm-build
          ];
          inputsFrom = [ rainix.devShells.${system}.default ];
        };
      }
    );
}
