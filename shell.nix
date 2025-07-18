{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  packages = [
    pkgs.nodejs
    pkgs.python3

    pkgs.tree-sitter
    pkgs.editorconfig-checker

    pkgs.rustc
    pkgs.cargo

    pkgs.emscripten

    # Formatters
    pkgs.treefmt
    pkgs.nixpkgs-fmt
    pkgs.prettier
    pkgs.rustfmt
    pkgs.clang-tools
  ];
}
