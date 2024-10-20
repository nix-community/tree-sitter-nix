{
  buildGoApplication,
  lib,
}:
buildGoApplication {
  pname = "flake-inputs";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  modules = ./gomod2nix.toml;

  ldflags = [
    "-s"
    "-w"
  ];

  subPackages = ["."];

  meta = {
    mainProgram = "flake-inputs";
  };
}
