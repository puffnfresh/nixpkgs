# Minimal Windows stdenv bootstrap tarball
#
# Contains Cygwin cross-compiled GNU tools for a POSIX-compatible
# build environment on Windows:
#   - GNU Bash (shell)
#   - GNU Coreutils, Findutils, Diffutils
#   - GNU Sed, Grep, Awk
#   - GNU Tar, Make, Patch
#   - gzip, bzip2, xz (archive tools)
#   - cygwin1.dll (POSIX compatibility layer)
#
let
  nativePkgs = import ../../.. { };

  crossPkgs = import ../../.. {
    crossSystem.config = "x86_64-pc-cygwin";
  };

  inherit (nativePkgs) lib;

  # Packages whose executables go into the bootstrap tarball.
  packages = with crossPkgs; [
    bash
    coreutils
    findutils
    diffutils
    gnused
    gnugrep
    gawk
    gnutar
    gnumake
    patch
    gzip
    bzip2.bin
    xz.bin
  ];

  # Use closureInfo to find every store path in the runtime closure,
  # so we can collect all required DLLs (cygwin1.dll, cygiconv, etc.).
  closureInfo = nativePkgs.closureInfo {
    rootPaths = packages ++ [
      crossPkgs.cygwin.newlib-cygwin
      crossPkgs.cygwin.newlib-cygwin.bin
    ];
  };

in
nativePkgs.stdenvNoCC.mkDerivation {
  name = "windows-bootstrap-tools";

  nativeBuildInputs = [ nativePkgs.xz ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/pack/bin

    # Copy executables from each package
    for pkg in ${lib.concatMapStringsSep " " toString packages}; do
      if [ -d "$pkg/bin" ]; then
        for f in "$pkg/bin"/*.exe; do
          if [ -e "$f" ]; then
            cp -nv "$f" $out/pack/bin/ || true
          fi
        done
        # Some packages (e.g. gzip) wrap the real .exe behind a shell
        # script and hide it as .foo.exe.  Copy those as foo.exe.
        for f in "$pkg/bin"/.*.exe; do
          if [ -e "$f" ]; then
            name="$(basename "$f")"       # .gzip.exe
            name="''${name#.}"            # gzip.exe
            cp -nv "$f" "$out/pack/bin/$name" || true
          fi
        done
      fi
    done

    # Provide sh.exe alias for bash
    if [ ! -e $out/pack/bin/sh.exe ]; then
      ln $out/pack/bin/bash.exe $out/pack/bin/sh.exe
    fi

    # Collect all DLLs from the full runtime closure
    for path in $(cat ${closureInfo}/store-paths); do
      for dir in "$path/bin" "$path/lib"; do
        if [ -d "$dir" ]; then
          for f in "$dir"/*.dll; do
            if [ -e "$f" ]; then
              cp -nv "$f" $out/pack/bin/ || true
            fi
          done
        fi
      done
    done

    # Add marker file so builtins.fetchTarball doesn't strip bin/
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
    description = "Minimal Windows stdenv bootstrap tarball (Cygwin GNU tools)";
    platforms = lib.platforms.linux;
  };
}
