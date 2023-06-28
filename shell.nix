{ pkgs ? import <nixpkgs> { } }:

(pkgs.callPackage ./. { src = null; }).overrideAttrs(old: {
  nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
    pkgs.nodejs
    pkgs.tree-sitter
    pkgs.editorconfig-checker
  ];
})
