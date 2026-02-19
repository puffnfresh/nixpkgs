{
  lib,
  stdenv,
  buildPackages,
  fetchFromGitHub,
  rustPlatform,
  python3Packages,
  versionCheckHook,
  nix-update-script,

  prefix ? "uutils-",
  buildMulticallBinary ? true,

  selinuxSupport ? false,
  libselinux,

  acl,
  windows,
}:

assert selinuxSupport -> lib.meta.availableOn stdenv.hostPlatform libselinux;

stdenv.mkDerivation (finalAttrs: {
  pname = "uutils-coreutils";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "uutils";
    repo = "coreutils";
    tag = finalAttrs.version;
    hash = "sha256-/GLDcqbNRO2NV+tW5yRZ0BdGJ+R3S3CPBPuBXpCIWuU=";
  };

  # error: linker `aarch64-linux-gnu-gcc` not found
  postPatch = ''
    rm .cargo/config.toml
  '' + lib.optionalString (stdenv.hostPlatform != stdenv.buildPlatform) ''
    # uudoc cannot be cross-compiled; remove it from install dependencies
    sed -i 's/install: build install-manpages install-completions install-locales/install: build/' GNUmakefile
  '' + lib.optionalString stdenv.hostPlatform.isWindows ''
    # The Makefile doesn't account for the .exe suffix on Windows
    sed -i 's|$(BUILDDIR)/coreutils $(INSTALLDIR_BIN)|$(BUILDDIR)/coreutils.exe $(INSTALLDIR_BIN)|' GNUmakefile
    sed -i 's|$(BUILDDIR)/$(prog) $(INSTALLDIR_BIN)|$(BUILDDIR)/$(prog).exe $(INSTALLDIR_BIN)|' GNUmakefile
  '';

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname src version;
    hash = "sha256-DrDfbf7UMEeNRvCHsu1Kbr+4PWkckmMvy8sEpjEgJfg=";
  };

  buildInputs =
    lib.optionals (lib.meta.availableOn stdenv.hostPlatform acl) [
      acl
    ]
    ++ lib.optionals selinuxSupport [
      libselinux
    ]
    ++ lib.optionals stdenv.hostPlatform.isWindows [
      windows.pthreads
    ];

  nativeBuildInputs = [
    rustPlatform.bindgenHook
    rustPlatform.cargoSetupHook
    python3Packages.sphinx
  ];

  makeFlags = [
    "CARGO=${lib.getExe buildPackages.cargo}"
    "PREFIX=${placeholder "out"}"
    "PROFILE=release"
    "SELINUX_ENABLED=${if selinuxSupport then "1" else "0"}"
    "INSTALLDIR_MAN=${placeholder "out"}/share/man/man1"
    # Explicitly enable acl (except on Windows), and if requested selinux.
    # We cannot rely on SELINUX_ENABLED here since our explicit assignment
    # overrides its effect in the makefile.
    "BUILD_SPEC_FEATURE=${
      lib.concatStringsSep "," (
        # We can always enable acl, on non-Linux, libc provides the headers,
        # only in Linux we need to add the acl lib to buildInputs.
        lib.optionals (!stdenv.hostPlatform.isWindows) [
          "feat_acl"
        ]
        ++ (lib.optionals selinuxSupport [
          "feat_selinux"
        ])
      )
    }"
  ]
  ++ lib.optionals (prefix != null) [ "PROG_PREFIX=${prefix}" ]
  ++ lib.optionals buildMulticallBinary [ "MULTICALL=y" ]
;

  # Skip utils that are unavailable on Windows:
  # these use Unix-only APIs (LD_PRELOAD, Unix signals, file modes, utmp, etc.)
  preBuild = lib.optionalString stdenv.hostPlatform.isWindows ''
    makeFlagsArray+=("SKIP_UTILS=chgrp chmod chown chroot groups hostid id install kill logname mkfifo mknod nice nohup pathchk pinky stat stdbuf stty timeout tty uptime users who")
  '';


  env = lib.optionalAttrs (stdenv.hostPlatform != stdenv.buildPlatform) {
    CARGO_BUILD_TARGET = stdenv.hostPlatform.rust.rustcTarget;
  } // lib.optionalAttrs selinuxSupport {
    SELINUX_INCLUDE_DIR = "${libselinux.dev}/include";
    SELINUX_LIB_DIR = lib.makeLibraryPath [
      libselinux
    ];
    SELINUX_STATIC = "0";
  };

  # too many impure/platform-dependent tests
  doCheck = false;

  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  versionCheckProgram =
    let
      prefix' = lib.optionalString (prefix != null) prefix;
    in
    "${placeholder "out"}/bin/${prefix'}ls";
  doInstallCheck = stdenv.hostPlatform == stdenv.buildPlatform;

  passthru = {
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Cross-platform Rust rewrite of the GNU coreutils";
    longDescription = ''
      uutils is an attempt at writing universal (as in cross-platform)
      CLI utils in Rust. This repo is to aggregate the GNU coreutils rewrites.
    '';
    homepage = "https://github.com/uutils/coreutils";
    changelog = "https://github.com/uutils/coreutils/releases/tag/${finalAttrs.version}";
    maintainers = with lib.maintainers; [
      siraben
      matthiasbeyer
    ];
    license = lib.licenses.mit;
    platforms = lib.platforms.unix ++ lib.platforms.windows;
  };
})
