# Builds a script to start a Linux x86_64 remote builder using Hyperkit. The kernel and initrd from Nix. We can't
# build these from Darwin yet, so we just cross our fingers that either:

# 1. There's a binary substitute available
# 2. There's already a remote builder capable of building it

# The VM runs SSH with Nix available, so we can use it as a remote builder.

# TODO: Sadly this file has lots of duplication with vmTools.
# TODO: We should probably use vpnkit instead of vmnet
# TODO: Quick boot and caching via OverlayFS and a 9P (via diod) /nix/store

{ system
, stdenv
, perl
, xz
, bash
, nix
, pathsFromGraph
, hyperkit
, writeScript
, writeScriptBin
, writeText
, forceSystem
, vmTools
, makeInitrd

, storeDir ? builtins.storeDir

, uuid ? "5ac40642-a699-4c14-b8f0-be08f17807c9"
, authorizedKeys ? ./default-key.pub
, privateKey ? ./default-key
}:

let
  pkgsLinux = forceSystem "x86_64-linux" "x86_64";
  vmToolsLinux = vmTools.override { pkgs = pkgsLinux; };

  hd = "vda";
  systemTarball = import <nixpkgs/nixos/lib/make-system-tarball.nix> {
    inherit stdenv perl xz pathsFromGraph;
    contents = [];
    storeContents = [
      {
        object = stage2Init;
        symlink = "none";
      }
    ];
  };
  createDeviceNodes = dev:
    ''
      mknod -m 666 ${dev}/null    c 1 3
      mknod -m 666 ${dev}/zero    c 1 5
      mknod -m 666 ${dev}/random  c 1 8
      mknod -m 666 ${dev}/urandom c 1 9
      mknod -m 666 ${dev}/tty     c 5 0
      mknod -m 666 ${dev}/ttyS0   c 4 64
      mknod -m 666 ${dev}/ttyS1   c 4 65
      mknod ${dev}/rtc     c 254 0
      . /sys/class/block/${hd}/uevent && mknod ${dev}/${hd} b $MAJOR $MINOR || true
    '';
  stage1Init = writeScript "vm-run-stage1" ''
    #! ${vmToolsLinux.initrdUtils}/bin/ash -e

    export PATH=${vmToolsLinux.initrdUtils}/bin

    mkdir /etc
    echo -n > /etc/fstab

    mount -t proc none /proc
    mount -t sysfs none /sys

    echo 2 > /proc/sys/vm/panic_on_oom

    echo "loading kernel modules..."
    for i in $(cat ${vmToolsLinux.modulesClosure}/insmod-list); do
      insmod $i
    done

    mount -t tmpfs none /dev
    ${createDeviceNodes "/dev"}
    ln -s /proc/self/fd /dev/fd

    ifconfig lo up

    mkdir /fs

    mount /dev/${hd} /fs 2>/dev/null || {
      ${pkgsLinux.e2fsprogs}/bin/mkfs.ext4 -q /dev/${hd}
      mount /dev/${hd} /fs
    } || true

    mkdir -p /fs/dev
    mount -o bind /dev /fs/dev

    mkdir -p /fs/dev/shm /fs/dev/pts
    mount -t tmpfs -o "mode=1777" none /fs/dev/shm
    mount -t devpts none /fs/dev/pts

    echo "extracting Nix store..."
    tar -C /fs -xf ${systemTarball}/tarball/nixos-system-${system}.tar.xz nix

    mkdir -p /fs/tmp /fs/run /fs/var
    mount -t tmpfs -o "mode=1777" none /fs/tmp
    mount -t tmpfs -o "mode=755" none /fs/run
    ln -sfn /run /fs/var/run

    mkdir -p /fs/proc
    mount -t proc none /fs/proc

    mkdir -p /fs/sys
    mount -t sysfs none /fs/sys

    mkdir -p /fs/etc
    ln -sf /proc/mounts /fs/etc/mtab
    echo "127.0.0.1 localhost" > /fs/etc/hosts

    echo "starting stage 2 ($command)"
    exec switch_root /fs $command
  '';

  sshdConfig = writeText "hyperkit-sshd-config" ''
    PermitRootLogin yes
    PasswordAuthentication no
    ChallengeResponseAuthentication no
  '';
  stage2Init = writeScript "vm-run-stage2" ''
    #! ${pkgsLinux.bash}/bin/bash

    export NIX_STORE=${storeDir}
    export NIX_BUILD_TOP=/tmp
    export TMPDIR=/tmp
    cd "$NIX_BUILD_TOP"

    ${pkgsLinux.coreutils}/bin/mkdir -p /bin
    ${pkgsLinux.coreutils}/bin/ln -fs ${pkgsLinux.bash}/bin/sh /bin/sh

    # # Set up automatic kernel module loading.
    export MODULE_DIR=${pkgsLinux.linux}/lib/modules/
    ${pkgsLinux.coreutils}/bin/cat <<EOF > /run/modprobe
    #! /bin/sh
    export MODULE_DIR=$MODULE_DIR
    exec ${pkgsLinux.kmod}/bin/modprobe "\$@"
    EOF
    ${pkgsLinux.coreutils}/bin/chmod 755 /run/modprobe
    echo /run/modprobe > /proc/sys/kernel/modprobe
    ${pkgsLinux.kmod}/bin/modprobe virtio_net

    echo "root:x:0:0:System administrator:/root:${pkgsLinux.bash}/bin/bash" >> /etc/passwd
    echo "sshd:x:1:65534:SSH privilege separation user:/var/empty:${pkgsLinux.shadow}/bin/nologin" >> /etc/passwd
    echo "nixbld1:x:30001:30000:Nix build user 1:/var/empty:${pkgsLinux.shadow}/bin/nologin" >> /etc/passwd
    echo "nixbld:x:30000:nixbld1" >> /etc/group

    export PATH="${vmToolsLinux.initrdUtils}/bin:${pkgsLinux.nix}/bin"
    ln -s /dev/pts/ptmx /dev/ptmx
    mkdir -p /etc/ssh /root/.ssh /var/db /var/empty
    ${pkgsLinux.dhcp}/bin/dhclient -v eth0
    ifconfig eth0 | ${pkgsLinux.perl}/bin/perl -n -e '/inet addr:([^ ]*)/ && print $1' > /dev/ttyS1
    ${pkgsLinux.openssh}/bin/ssh-keygen -A
    echo "export PATH=$PATH" >> /root/.bashrc
    cp ${authorizedKeys} /root/.ssh/authorized_keys
    chmod 0644 /root/.ssh/authorized_keys
    exec ${pkgsLinux.openssh}/bin/sshd -D -e -f ${sshdConfig}
  '';

  img = "bzImage";
  initrd = makeInitrd {
    contents = [
      { object = stage1Init;
        symlink = "/init";
      }
    ];
  };
  startHyperkitBuilder = ''
    #!${bash}/bin/bash

    TMPDIR="/tmp"
    TMPDIR="$(mktemp -d)"

    ${hyperkit}/bin/hyperkit \
      -A \
      -s 0,hostbridge \
      -s 1,lpc \
      -s 2,virtio-rnd \
      -s 3,virtio-net \
      -l com1,stdio \
      -l com2,autopty,log=$TMPDIR/nix-hyperkit-ip \
      -U ${uuid} \
      -f kexec,${pkgsLinux.linux}/${img},${initrd}/initrd,"console=ttyS0 panic=1 command=${stage2Init} loglevel=4" \
      $@ &>"$TMPDIR/hyperkit.log" &

    echo -n "Waiting for Hyperkit to send the VM's IP" >&2
    # Wait until the file looks like an IP
    until ip="$(grep -aoE "[0-9.]+" "$TMPDIR/nix-hyperkit-ip" 2>/dev/null)"; do
      echo -n '.' >&2
      sleep 1
    done
    echo >&2

    cp ${privateKey} "$TMPDIR/private-key"
    chmod 0600 "$TMPDIR/private-key"
    echo "root@$ip x86_64-linux $TMPDIR/private-key 1" > "$TMPDIR/remote-systems"

    echo "Hyperkit is now running. Source the following script:" >&2

    echo "sudo chown -R \"\$USER\" \"$TMPDIR\""
    echo "nix-hyperkit-builder-stop() { ssh -i \"$TMPDIR/private-key\" root@$ip poweroff -f & rm -r \"$TMPDIR\" & }"
    echo "export NIX_BUILD_HOOK='${nix}/libexec/nix/build-remote.pl'"
    echo "export NIX_REMOTE_SYSTEMS='$TMPDIR/remote-systems'"
    echo "export NIX_CURRENT_LOAD='$TMPDIR/current-load'"
  '';
in
writeScriptBin "nix-hyperkit-builder" startHyperkitBuilder
