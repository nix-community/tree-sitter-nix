{
  projectRootFile = "flake.nix";
  programs = {
    # clang
    clang-format.enable = true;

    # deno (faster compared to prettier)
    deno.enable = true;

    # json
    jsonfmt.enable = true;

    # markdown
    mdformat.enable = true;

    # nix
    alejandra.enable = true;
    deadnix.enable = true;
    statix.enable = true;

    # swift
    swift-format.enable = true;

    # rust
    rustfmt = {
      enable = true;
      edition = "2018";
    };

    # shell
    shfmt.enable = true;

    # yaml
    yamlfmt.enable = true;
  };
  settings.formatter = {
    # clang-format
    clang-format = {
      excludes = [
        "bindings/node/binding.cc"
        "src/parser.c"
        "src/tree_sitter/alloc.h"
        "src/tree_sitter/array.h"
        "src/tree_sitter/parser.h"
      ];
    };

    # deno
    deno = {
      includes = ["*.js"];
      excludes = ["*.json"];
    };

    # jsonfmt
    jsonfmt = {
      excludes = ["src/**.json"];
    };

    # nix
    statix = {
      priority = 1;
      excludes = ["test/*"];
    };
    deadnix = {
      priority = 2;
      excludes = ["test/*"];
    };
    alejandra = {
      priority = 3;
      excludes = ["test/*"];
    };

    # yaml
    yamlfmt.includes = ["*.yaml" "*.yml" "*.yamlfmt"];
  };
}
