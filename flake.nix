{
  description = "tree-sitter-nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    npmlock2nix = {
      url = "github:nix-community/npmlock2nix";
      flake = false;
    };

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, npmlock2nix, crane }: (
    (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs) lib;

        npmlock2nix' = pkgs.callPackage npmlock2nix { };
        craneLib = crane.lib.${system};

      in
      {
        checks = {
          editorconfig = pkgs.runCommand "editorconfig" {
            nativeBuildInputs = [ pkgs.editorconfig-checker ];
          } ''
            cd ${self}
            editorconfig-checker
            touch $out
          '';

          # If the generated code differs from the checked in we need
          # to check in the newly generated sources.
          generated-diff = pkgs.runCommand "generated-diff" {
            nativeBuildInputs = [ pkgs.tree-sitter pkgs.nodejs ];
          } ''
            cp -rv ${self} src
            chmod +w -R src
            cd src

            HOME=. npm run generate
            diff -r src/ ${self}/src

            touch $out
          '';

          build = self.packages.${system}.tree-sitter-nix;

          rust-bindings = craneLib.buildPackage {
            src = self;
          };
        } // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
          # Requires xcode
          node-bindings = npmlock2nix'.v2.build {
            src = self;
            inherit (self.devShells.${system}.default) nativeBuildInputs;
            inherit (pkgs) nodejs;

            buildCommands = [
              "${pkgs.nodePackages.node-gyp}/bin/node-gyp configure"
              "npm run build"
            ];

            installPhase = ''
              touch $out
            '';
          };

        };

        packages.tree-sitter-nix = pkgs.callPackage ./default.nix { src = self; };
        packages.default = self.packages.${system}.tree-sitter-nix;
        devShells.default = pkgs.callPackage ./shell.nix { };
      }))
  );
}
