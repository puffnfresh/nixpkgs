
{ stdenv
, lib
, cmake
, fetchFromGitHub
, fetchpatch
, natron
, pkg-config
, substitute

, ffmpeg
, libGL
, libGLU
, libpng
, libraw
, libwebp
, opencolorio_1
, openexr
, openimageio
, openjpeg
, seexpr
}:

let
  # Migration from SeExpr2 to SeExpr3 is WIP for openfx-io
  seexpr2 =
    seexpr.overrideAttrs (attrs: rec {
      version = "2.11";
      # src = /tmp/SeExpr;
      src = fetchFromGitHub {
        owner = "wdas";
        repo = "SeExpr";
        rev = "v${version}";
        sha256 = "sha256-hKZBeIcCzXFuJefRxZKjBXNRBLufvMedGbQZJ02ZhCg=";
      };
      patches = [
        ./seexpr2.patch
      ];
      postPatch = null;
    });
in
stdenv.mkDerivation {
  pname = "openfx-io";
  inherit (natron) version;
  src = fetchFromGitHub {
    owner = "NatronGitHub";
    repo = "openfx-io";
    rev = "Natron-${natron.version}";
    fetchSubmodules = true;
    sha256 = "sha256-ctJ4LK38b6p3wFOwt2LtlA3iniRm/942EfJ1w/3+wXM=";
  };
  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [
    ffmpeg
    libGL
    libGLU
    libpng
    libraw
    libwebp
    opencolorio_1
    openexr
    openimageio
    openjpeg

    seexpr2
  ];

  patches = [
    (substitute {
      src = fetchpatch {
        url = "https://github.com/NatronGitHub/openfx-supportext/commit/3b39e03f7e746a7779cfb47849796d97b6b522bb.patch";
        sha256 = "sha256-kCcSj5cCHepE+vRZdHvPhEwgv0LFr1tK0lZDugaaaDs=";
      };
      # patch is in scope of a submodule, so that needs to be added
      replacements = [
        "--replace /glad/ /SupportExt/glad/"
      ];
    })
  ];

  cmakeFlags = [
    "-DCONFIG=release"

    # build will default to legacy
    "-DOpenGL_GL_PREFERENCE=GLVND"

    # for some reason not linked in, can't figure out why
    "-DSEEXPR2_LIBRARIES=${seexpr2}/lib/libSeExpr.so"
  ];

  meta = {
    description = "A set of Readers/Writers plugins written using the OpenFX standard";
    homepage = "https://natron.fr/";
    license = lib.licenses.gpl2;
    maintainers = [ lib.maintainers.puffnfresh ];
    platforms = lib.platforms.linux;
  };
}
