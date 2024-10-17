{pkgs, ...}:
pkgs.mkShell {
  packages = with pkgs; [
    nodejs
    python3

    tree-sitter
    editorconfig-checker

    rustc
    cargo

    go
    gcc
  ];
}
