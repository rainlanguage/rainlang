let
    pkgs = import
        (builtins.fetchTarball https://github.com/NixOS/nixpkgs/archive/nixos-23.11.tar.gz )
        {};

    local-test = pkgs.writeShellScriptBin "local-test" ''
        npm test
    '';

    flush = pkgs.writeShellScriptBin "flush" ''
        rm -rf dist
        rm -rf docs
    '';

    flush-all = pkgs.writeShellScriptBin "flush-all" ''
        flush
        rm -rf node_modules
    '';

    ci-test = pkgs.writeShellScriptBin "ci-test" ''
        flush-all
        npm install
        local-test
    '';

    build-cjs = pkgs.writeShellScriptBin "build-cjs" ''
        npm run build-cjs
    '';

    build-esm = pkgs.writeShellScriptBin "build-esm" ''
        npm run build-esm
    '';

    build = pkgs.writeShellScriptBin "build" ''
        npm run build
    '';

    build-all = pkgs.writeShellScriptBin "build-all" ''
        flush-all
        npm install
    '';

    docgen = pkgs.writeShellScriptBin "docgen" ''
        npm run docgen
    '';

    lint = pkgs.writeShellScriptBin "lint" ''
        npm run lint
    '';

    lint-fix = pkgs.writeShellScriptBin "lint-fix" ''
        npm run lint-fix
    '';

    in
    pkgs.mkShell {
        name = "shell";
        buildInputs = [
            pkgs.emscripten
            pkgs.nixpkgs-fmt
            pkgs.yarn
            pkgs.nodejs-18_x
            build
            build-cjs
            build-esm
            build-all
            local-test
            ci-test
            flush
            flush-all
            docgen
            lint
            lint-fix
        ] ++ (pkgs.lib.optionals pkgs.stdenv.isDarwin [
            pkgs.libiconv
            pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
        ]);
        shellHook = ''
            export PATH=$( npm bin ):$PATH
            # keep it fresh
            npm install
        '';
    }
    
