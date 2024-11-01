{ lib
, stdenvNoCC
, fetchzip
, fetchFromGitHub
, fetchpatch
, mingw_w64_headers
}:

stdenvNoCC.mkDerivation rec {
  pname = "cygwin-headers";
  version = "3.5.4";

  src = fetchFromGitHub {
    owner = "mirror";
    repo = "newlib-cygwin";
    # TODO: Wrong revision for version
    rev = "1b7c72fdcc4bde7520407d2d3364146f04fb8312";
    hash = "sha256-ZFZ6igY1dPokZuI5gcUi7iUtZwKXv+AbQqkZocC0Qig=";
  };

  patches = [
    (fetchpatch {
      url = "https://raw.githubusercontent.com/Windows-on-ARM-Experiments/mingw-woarm64-build/371102dfa23b3e56b6759e1a44026d0640d55223/patches/cygwin/0001-before-autogen.patch";
      sha256 = "sha256-1JsbfYAPpsQSjknZcKfJOHA0RcdmgzkzAI4RcHG1kpA=";
    })
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/include/
    ln -s ${mingw_w64_headers}/include/w32api $out/include/
    cp -r newlib/libc/include/* $out/include/
    cp -r winsup/cygwin/include/* $out/include/
  '';

  meta = {
    platforms = lib.platforms.windows;
  };
}
