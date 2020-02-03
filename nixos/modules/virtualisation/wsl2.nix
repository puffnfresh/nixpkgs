{ pkgs, config, lib, ... }:

{
  boot.isContainer = true;

  system.build.tarball = pkgs.callPackage ../../lib/make-system-tarball.nix {
    compressCommand = "gzip";
    compressionExtension = ".gz";
    extraInputs = [ ];

    contents = [ ];
    extraArgs = "--owner=0";

    storeContents = map (x: { object = x; symlink = "none"; }) [
      config.system.build.toplevel
      pkgs.stdenv
    ];
  };

  systemd.package = pkgs.wsl-systemd-wrapper;

  services.nscd.enable = false;
  networking.firewall.enable = false;
}
