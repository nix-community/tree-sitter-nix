{ pkgs ? import <nixpkgs> { } }:

(pkgs.callPackage ./. { src = null; }).overrideAttrs (old: {
  nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
    pkgs.nodejs
    pkgs.python3

    pkgs.tree-sitter
    pkgs.editorconfig-checker

    pkgs.rustc
    pkgs.cargo

    # Formatters
    pkgs.treefmt
    pkgs.nixpkgs-fmt
  ];
})
