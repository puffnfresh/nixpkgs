# Minimal Windows stdenv
#
# Uses cross-compiled Rust reimplementations of standard Unix tools from
# a bootstrap tarball as the initial build environment:
#   - Brush (bash-compatible shell)
#   - uutils-coreutils
#   - uutils-findutils (find, xargs)
#   - uutils-diffutils (diff, cmp)
#   - uutils-sed
#   - uutils-tar
#
# This is an in-progress stdenv with no C compiler.
{
  lib,
  localSystem,
  crossSystem,
  config,
  overlays,
  crossOverlays ? [ ],
}:

assert crossSystem == localSystem;

let
  inherit (localSystem) system;

  bootstrapFiles =
    let
      table = {
        x86_64-windows = import ./bootstrap-files/x86_64-w64-mingw32.nix;
      };
    in
    table.${system} or (throw "unsupported Windows platform: ${system}");

  bootstrapTools = bootstrapFiles.bootstrapTools;

  fetchurlBoot = import ../../build-support/fetchurl/boot.nix {
    inherit system;
    inherit (config) rewriteURL;
  };

in
[
  # Stage 0: raw attributes, no stdenv yet.
  ({ }:
  {
    __raw = true;
    stdenv = { };
    gcc-unwrapped = null;
    binutils = null;
    coreutils = null;
    gnugrep = null;
  })

  # Stage 1: minimal stdenv with brush and no C compiler.
  (prevStage:
  {
    inherit config overlays;
    stdenv = import ../generic {
      name = "stdenv-windows";

      buildPlatform = localSystem;
      hostPlatform = localSystem;
      targetPlatform = localSystem;

      inherit config;

      shell = "${bootstrapTools}/bin/bash.exe";

      initialPath = [ bootstrapTools ];

      cc = null;

      inherit fetchurlBoot;

      preHook = ''
        # No ELF binaries on Windows.
        export NIX_DONT_SET_RPATH=1
        export NIX_NO_SELF_RPATH=1

        dontPatchShebangs=1
        dontPatchELF=1
        dontStrip=1
      '';

      extraAttrs = {
        inherit bootstrapTools;
        shellPackage = bootstrapTools;
      };
    };
  })
]
