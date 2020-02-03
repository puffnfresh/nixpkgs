{ stdenv, writeShellScript, runtimeShell, procps, systemd, utillinux, lndir, daemonize }:

let
  systemd-find =
    writeShellScript "wsl-systemd-find" ''
      ${procps}/bin/pgrep -xf ${systemd}/lib/systemd/systemd || (echo "Can't find running systemd" >&2; exit 1)
    '';
  systemd-run =
    writeShellScript "wsl-systemd-run" ''
      exec ${utillinux}/bin/nsenter -t "$(${systemd-find})" -S $UID -m -p ${systemd}/bin/$(basename $0) $@
    '';
in
stdenv.mkDerivation {
  name = "wsl-systemd-wrapper";
  dontUnpack = true;
  nativeBuildInputs = [ lndir ];
  installPhase = ''
    mkdir $out
    lndir ${systemd} $out

    unlink $out/lib/systemd/systemd
    cat > $out/lib/systemd/systemd <<EOF
    #!${runtimeShell}
    exec ${daemonize}/bin/daemonize ${utillinux}/bin/unshare -fp --propagation shared --mount-proc "${systemd}/lib/systemd/systemd" $@
    EOF
    chmod +x $out/lib/systemd/systemd

    for bin in $out/bin/*; do
      unlink $bin
      ln -s ${systemd-run} $bin
    done

    unlink $out/bin/systemctl
    cat > $out/bin/systemctl <<EOF
    #!${runtimeShell}
    if [ "\$1" = "daemon-reexec" ]; then
      kill "\$(${systemd-find})"
      while ${systemd-find} >/dev/null 2>/dev/null; do
        echo "Waiting for systemd to exit"
        sleep 1
      done
      $out/lib/systemd/systemd
      echo -n "Waiting for systemd to start"
      while ! systemctl is-system-running >/dev/null 2>/dev/null; do
        echo -n "."
        sleep 1
      done
      echo
      dbus-send --system --print-reply --dest=org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager.ListUnitsByPatterns array:string: array:string:
      exit 0
    fi
    exec ${utillinux}/bin/nsenter -t "\$(${systemd-find})" -S \$UID -m -p ${systemd}/bin/systemctl \$@
    EOF
    chmod +x $out/bin/systemctl
  '';
  inherit (systemd) passthru;
}
