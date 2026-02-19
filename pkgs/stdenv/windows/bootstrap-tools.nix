# Minimal Windows stdenv bootstrap tarball
#
# Contains cross-compiled Rust reimplementations of standard Unix tools
# for a minimal build environment on Windows:
#   - Brush (bash-compatible shell)
#   - uutils-coreutils
#   - uutils-findutils (find, xargs)
#   - uutils-diffutils (diff, cmp)
#   - uutils-sed
#   - uutils-tar
#
let
  nativePkgs = import ../../.. { };

  crossPkgs = import ../../.. {
    crossSystem.config = "x86_64-w64-mingw32";
  };

  inherit (nativePkgs) lib;

  brush = crossPkgs.brush;

  uutils-coreutils = crossPkgs.uutils-coreutils.override {
    prefix = null;
  };

  uutils-findutils = crossPkgs.uutils-findutils;
  uutils-diffutils = crossPkgs.uutils-diffutils;
  uutils-sed = crossPkgs.uutils-sed;
  uutils-tar = crossPkgs.uutils-tar;

  # The subcommands to create hardlinks for
  coreutilsPrograms = [
    "arch" "b2sum" "base32" "base64" "basename" "basenc"
    "cat" "cksum" "comm" "cp" "csplit" "cut"
    "date" "dd" "df" "dir" "dircolors" "dirname"
    "du" "echo" "env" "expand" "expr" "factor" "false" "fmt"
    "fold" "head" "hostname" "join" "link" "ln" "ls"
    "md5sum" "mkdir" "mktemp" "more" "mv" "nl" "nproc" "numfmt"
    "od" "paste" "pr" "printenv" "printf" "ptx" "pwd"
    "readlink" "realpath" "rm" "rmdir"
    "seq" "sha1sum" "sha224sum" "sha256sum" "sha384sum" "sha512sum"
    "shred" "shuf" "sleep" "sort" "split" "sum" "sync"
    "tac" "tail" "tee" "test" "touch" "tr" "true"
    "truncate" "tsort" "uname" "unexpand" "uniq" "unlink"
    "vdir" "wc" "whoami" "yes"
  ];

in
nativePkgs.stdenvNoCC.mkDerivation {
  name = "windows-bootstrap-tools";

  nativeBuildInputs = [ nativePkgs.xz ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/pack/bin

    cp -v ${brush}/bin/brush.exe $out/pack/bin/brush.exe
    # Provide bash.exe and sh.exe aliases
    cp -v ${brush}/bin/brush.exe $out/pack/bin/bash.exe
    cp -v ${brush}/bin/brush.exe $out/pack/bin/sh.exe

    cp -v ${uutils-coreutils}/bin/coreutils $out/pack/bin/coreutils.exe
    ${lib.concatMapStringsSep "\n" (prog:
      "ln $out/pack/bin/coreutils.exe $out/pack/bin/${prog}.exe"
    ) coreutilsPrograms}

    cp -v ${uutils-findutils}/bin/find.exe $out/pack/bin/find.exe
    cp -v ${uutils-findutils}/bin/xargs.exe $out/pack/bin/xargs.exe

    cp -v ${uutils-diffutils}/bin/diffutils.exe $out/pack/bin/diffutils.exe
    ln $out/pack/bin/diffutils.exe $out/pack/bin/diff.exe
    ln $out/pack/bin/diffutils.exe $out/pack/bin/cmp.exe

    cp -v ${uutils-sed}/bin/sed.exe $out/pack/bin/sed.exe

    cp -v ${uutils-tar}/bin/tarapp.exe $out/pack/bin/tar.exe

    for dir in ${brush}/bin ${uutils-coreutils}/bin ${uutils-findutils}/bin ${uutils-diffutils}/bin ${uutils-sed}/bin ${uutils-tar}/bin; do
      for dll in "$dir"/*.dll; do
        if [ -e "$dll" ]; then
          cp -nv "$dll" $out/pack/bin/ || true
        fi
      done
    done

    # Add a file so builtins.fetchTarball doesn't strip bin/
    echo "windows-bootstrap-tools" > $out/pack/.id

    mkdir -p $out/on-server
    XZ_OPT="-9 -e" tar cvJf $out/on-server/bootstrap-tools.tar.xz \
      --hard-dereference \
      --sort=name \
      --numeric-owner \
      --owner=0 --group=0 \
      --mtime=@1 \
      -C $out/pack .

    runHook postInstall
  '';

  meta = {
    description = "Minimal Windows stdenv bootstrap tarball (brush + uutils)";
    platforms = lib.platforms.linux;
  };
}
