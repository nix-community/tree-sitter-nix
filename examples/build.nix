# https://github.com/justinwoo/easy-purescript-nix/blob/7255d015b80d28c7c6db655dda215535cb2d4b41/purs.nix
{ pkgs ? import <nixpkgs> {} }:

let
  dynamic-linker = pkgs.stdenv.cc.bintools.dynamicLinker;

  patchelf = libPath :
    if pkgs.stdenv.isDarwin
      then ""
      else
        ''
          chmod u+w $PURS
          patchelf --interpreter ${dynamic-linker} --set-rpath ${libPath} $PURS
          chmod u-w $PURS
        '';

in pkgs.stdenv.mkDerivation rec {
  name = "purs-simple";
  version = "v0.12.3";

  src =
    if pkgs.stdenv.isDarwin
    then
    pkgs.fetchurl {
      url = "https://github.com/purescript/purescript/releases/download/v0.12.3/macos.tar.gz";
      sha256 = "1f916gv4fz571l4jvr15xjnsvjyy4nljv2ii9njwlm7k6yr5m0qn";
    }
    else
    pkgs.fetchurl {
      url = "https://github.com/purescript/purescript/releases/download/v0.12.3/linux64.tar.gz";
      sha256 = "1fad862a2sv4njxbbcfzibbi585m6is3ywb94nmjl8ax254baj3i";
    };


  buildInputs = [ pkgs.zlib
                  pkgs.gmp
                  pkgs.ncurses5];
  libPath = pkgs.lib.makeLibraryPath buildInputs;
  dontStrip = true;

  installPhase = ''
    mkdir -p $out/bin
    PURS="$out/bin/purs"

    install -D -m555 -T purs $PURS
    ${patchelf libPath}

    mkdir -p $out/etc/bash_completion.d/
    $PURS --bash-completion-script $PURS > $out/etc/bash_completion.d/purs-completion.bash
  '';
}
