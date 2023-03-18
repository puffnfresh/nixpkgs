
{ stdenv
, lib
, cmake
, fetchFromGitHub
, natron

, libGL

, fetchurl
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
  pname = "openfx-misc";
  inherit (natron) version;
  src = fetchFromGitHub {
    owner = "NatronGitHub";
    repo = "openfx-misc";
    rev = "Natron-${natron.version}";
    fetchSubmodules = true;
    sha256 = "sha256-nKW6OCyLjmBktZ5knW9lSxF6ehm60ArOmjJN+Ekq6x0=";
  };
  nativeBuildInputs = [
    cmake
  ];
  buildInputs = [
    libGL
  ];

  patchPhase = ''
    cp "${inpainth}" CImg/Inpaint/inpaint.h
    # taken from the Makefile; it gets skipped if the file already exists
    patch -p0 -dCImg < CImg/Inpaint/inpaint.h.patch

    cp "${CImgh}" CImg/CImg.h
  '';

  cmakeFlags = [
    "-DCONFIG=release"

    # build will default to legacy
    "-DOpenGL_GL_PREFERENCE=GLVND"
  ];

  meta = {
    description = "Miscellaneous OFX / OpenFX / Open Effects plugins";
    homepage = "https://natron.fr/";
    license = lib.licenses.gpl2;
    maintainers = [ lib.maintainers.puffnfresh ];
    platforms = lib.platforms.linux;
  };
}
