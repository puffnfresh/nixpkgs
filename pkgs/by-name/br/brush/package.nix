{
  lib,
  rustPlatform,
  fetchFromGitHub,
  versionCheckHook,
  testers,
  runCommand,
  writeText,
  nix-update-script,
  brush,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "brush";
  version = "0.3.0-unstable-2026-02-18";

  src = fetchFromGitHub {
    owner = "reubeno";
    repo = "brush";
    rev = "b17ba985229af8d37b839388f50d0bc54cd49e44";
    hash = "sha256-1wsS/XiPX2NlyYWK13134PVOnis1tdZxUFGdM2bRpwM=";
  };

  cargoHash = "sha256-3dVkUQoYG+U//ta3U08HM1SrnKllge6YGNzQNIIhZ/k=";

  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  doInstallCheck = true;
  versionCheckProgram = "${placeholder "out"}/bin/${finalAttrs.meta.mainProgram}";

  # Found argument '--test-threads' which wasn't expected, or isn't valid in this context
  doCheck = false;

  passthru = {
    shellPath = "/bin/brush";

    tests = {
      complete = testers.testEqualContents {
        assertion = "brushinfo performs to inspect completions";
        expected = writeText "expected" ''
          brush
          brushctl
          brushinfo
        '';
        actual =
          runCommand "actual"
            {
              nativeBuildInputs = [ brush ];
            }
            ''
              brush -c 'brushinfo complete line bru' >$out
            '';
      };
    };

    updateScript = nix-update-script { extraArgs = [ "--version-regex=brush-shell-v([\\d\\.]+)" ]; };
  };

  meta = {
    description = "Bash/POSIX-compatible shell implemented in Rust";
    homepage = "https://github.com/reubeno/brush";
    changelog = "https://github.com/reubeno/brush/blob/${finalAttrs.src.rev}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ kachick ];
    mainProgram = "brush";
  };
})
