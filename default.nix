{ pkgs ? import <nixpkgs> { }
, lib ? pkgs.lib
}:

pkgs.tree-sitter-grammars.tree-sitter-nix.overrideAttrs (old: {
  name = "tree-sitter-nix-dev";
  version = "dev";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./queries/highlights.scm
      ./queries/injections.scm
      ./queries/locals.scm
      ./queries/tags.scm
      ./src/grammar.json
      ./src/node-types.json
      ./src/parser.c
      ./src/scanner.c
      ./src/tree_sitter/parser.h
    ];
  };

  doCheck = true;
  checkInputs = [
    pkgs.tree-sitter
    pkgs.nodejs
  ];
  checkPhase = ''
    HOME=$(mktemp -d) tree-sitter test
  '';
})
