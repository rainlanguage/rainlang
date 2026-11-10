{
  description = "Flake for development workflows.";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    rainix.url = "github:rainlanguage/rainix";
    rain.url = "github:rainlanguage/rain.cli";
    # rain.cli pulls its own rainix; make it follow ours so the lock has a
    # single rainix (and one rust toolchain / nixpkgs) instead of two revs.
    rain.inputs.rainix.follows = "rainix";
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
          # Resolved by test/src/lib/dotrain tests as the `rain dotrain compose` oracle.
          rain-cli = rain.defaultPackage.${system};

          rainlang-prelude = rainix.mkTask.${system} {
            name = "rainlang-prelude";
            body = ''
              set -euxo pipefail

              # Build the reference extern's meta, which its generated
              # pointers file hashes.
              mkdir -p meta;
              forge script --silent ./script/BuildAuthoringMeta.sol;
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
        }
        // rainix.packages.${system};

        devShells.default = pkgs.mkShell {
          inherit (rainix.devShells.${system}.default) shellHook;
          packages = [
            packages.rainlang-prelude
          ];
          inputsFrom = [ rainix.devShells.${system}.default ];
        };
      }
    );
}
