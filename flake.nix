{
  description = "tree-sitter-nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }: (
    (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

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

            tree-sitter generate
            diff -r src/ ${self}/src

            touch $out
          '';

          build = self.packages.${system}.tree-sitter-nix;
        };

        packages.tree-sitter-nix = pkgs.callPackage ./default.nix { src = self; };
        packages.default = self.packages.${system}.tree-sitter-nix;
        devShells.default = pkgs.callPackage ./shell.nix { };
      }))
  );
}
