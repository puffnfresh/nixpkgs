{ callPackage
}:

{
  openfx-arena = callPackage ./openfx-arena.nix { };
  openfx-gmic = callPackage ./openfx-gmic.nix { };
  openfx-io = callPackage ./openfx-io.nix { };
  openfx-misc = callPackage ./openfx-misc.nix { };
}
