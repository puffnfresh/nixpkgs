{ stdenv, lib, buildGoPackage, fetchgit }:

buildGoPackage rec {
  name = "go-p9p-${version}";
  version = "20170223-${stdenv.lib.strings.substring 0 7 rev}";
  rev = "87ae8514a3a2d9684994a6c319f96ba9e18a062e";

  goPackagePath = "github.com/docker/go-p9p";
  subPackages = [ "cmd/9ps" ];

  src = fetchgit {
    inherit rev;
    url = "https://github.com/docker/go-p9p";
    sha256 = "1ab7q7837j0pia735x2dsyqvai8n5ynhm7q7cj4rq2c108yqywj2";
  };

  goDeps = ./deps.nix;

  meta = with stdenv.lib; {
    description = "A modern, performant 9P library for Go";
    homepage = https://github.com/docker/go-p9p;
    license = licenses.asl20;
  };
}

