{ stdenv, lib, fetchFromGitHub, Hypervisor, vmnet, xpc, libobjc }:

let
  rev = "858492e3d919f8b49a39e1944a49e1d7b4a51e6d";
in
stdenv.mkDerivation rec {
  name    = "hyperkit-${version}";
  # HyperKit release binary uses 6 characters in the version
  version = lib.strings.substring 0 6 rev;

  src = fetchFromGitHub {
    owner = "moby";
    repo = "hyperkit";
    inherit rev;
    sha256 = "1ndl6dj2qbwns2dcp43xhp5k9zcjmxl5y0rz46d8b3zwm7ixf2xr";
  };

  buildInputs = [ Hypervisor vmnet xpc libobjc ];

  # Don't use git to determine version
  prePatch = ''
    substituteInPlace Makefile \
      --replace 'shell git describe --abbrev=6 --dirty --always --tags' "$version" \
      --replace 'shell git rev-parse HEAD' "${rev}" \
      --replace 'PHONY: clean' 'PHONY:'
    cp ${./dtrace.h} src/include/xhyve/dtrace.h
  '';

  makeFlags = [ "CFLAGS+=-Wno-shift-sign-overflow" ''CFLAGS+=-DVERSION=\"${version}\"'' ''CFLAGS+=-DVERSION_SHA1=\"${rev}\"'' ];
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
