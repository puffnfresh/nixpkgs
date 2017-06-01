{ stdenv, lib, fetchurl, Hypervisor, vmnet, xpc, libobjc }:

let
  fullHash = "70205a6d5143340299a679af259f70dfcd7cf8a4";
in
stdenv.mkDerivation rec {
  name    = "hyperkit-${version}";
  version = "70205a6d5";

  src = fetchurl {
    url    = "https://github.com/moby/hyperkit/archive/${fullHash}.tar.gz";
    sha256 = "0pcd8c52fwaq73c16nl9mc4bdzn9mr7x6albp679ymxhkd5h0h5p";
  };

  buildInputs = [ Hypervisor vmnet xpc libobjc ];

  # Don't use git to determine version
  prePatch = ''
    substituteInPlace Makefile \
      --replace 'shell git describe --abbrev=6 --dirty --always --tags' "$version" \
      --replace 'shell git rev-parse HEAD' "${fullHash}" \
      --replace 'PHONY: clean' 'PHONY:'
    cp ${./dtrace.h} src/include/xhyve/dtrace.h
  '';


  makeFlags = [ "CFLAGS+=-Wno-shift-sign-overflow" ''CFLAGS+=-DVERSION=\"${version}\"'' ''CFLAGS+=-DVERSION_SHA1=\"${fullHash}\"'' ];
  installPhase = ''
    mkdir -p $out/bin
    cp build/hyperkit $out/bin
  '';

  meta = {
    description = "Lightweight Virtualization on OS X Based on bhyve";
    homepage = "https://github.com/mist64/xhyve";
    maintainers = [ lib.maintainers.lnl7 ];
    platforms = lib.platforms.darwin;
  };
}
