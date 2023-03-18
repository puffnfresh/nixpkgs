
{ stdenv
, lib
, cmake
, fetchFromGitHub
, fetchurl
, natron
, pkg-config

, fribidi
, icu
, imagemagick
, libcdr
, libdatrie
, libdeflate
, librevenge
, librsvg
, libselinux
, libsepol
, libthai
, libXdmcp
, libxml2
, libzip
, pango
, pcre
, pcre2
, poppler
, poppler_gi
, util-linuxMinimal
}:

let
  cimgversion =
    "b33dcc8f9f1acf1f276ded92c04f8231f6c23fcd";
  CImgh =
    fetchurl {
      url = "https://raw.githubusercontent.com/dtschump/CImg/${cimgversion}/CImg.h";
      sha256 = "sha256-v4V0tV1r/FpISeQ4DVFOiIa9JrLzrwK5puNu6zKVIp8=";
    };
  inpainth =
    fetchurl {
      url = "https://raw.githubusercontent.com/dtschump/CImg/${cimgversion}/plugins/inpaint.h";
      sha256 = "sha256-cd28a3VOs5002GkthHkbIUrxZfKuGhqIYO4Oxe/2HIQ=";
    };
in
stdenv.mkDerivation {
  pname = "openfx-arena";
  inherit (natron) version;
  src = fetchFromGitHub {
    owner = "NatronGitHub";
    repo = "openfx-arena";
    rev = "Natron-${natron.version}";
    fetchSubmodules = true;
    sha256 = "sha256-1aKkIX9k7jY/Ou20b2TvSpA0IOdvyUUXOPRFFpCWbpo=";
  };
  nativeBuildInputs = [
    cmake
    pkg-config
  ];
  buildInputs = [
    pango
    poppler
    imagemagick
    libzip
    libxml2
    librsvg
    pcre2
    librevenge
    libcdr

    libXdmcp
    util-linuxMinimal
    libselinux
    libsepol
    pcre
    libdeflate
    fribidi
    libthai
    libdatrie
    icu
  ];

  env.NIX_CFLAGS_COMPILE =
    "-std=c++17 -I${lib.getDev poppler_gi}/include/poppler";

  meta = {
    description = "Extra OpenFX plugins for Natron";
    homepage = "https://natron.fr/";
    license = lib.licenses.gpl2;
    maintainers = [ lib.maintainers.puffnfresh ];
    platforms = lib.platforms.linux;
  };
}
