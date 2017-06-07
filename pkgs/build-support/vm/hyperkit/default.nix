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
, diod
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
}:

let
  pkgsLinux = forceSystem "x86_64-linux" "x86_64";
  vmToolsLinux = vmTools.override { pkgs = pkgsLinux; };

  createDeviceNodes = dev:
    ''
      mknod -m 666 ${dev}/null    c 1 3
      mknod -m 666 ${dev}/zero    c 1 5
      mknod -m 666 ${dev}/random  c 1 8
      mknod -m 666 ${dev}/urandom c 1 9
      mknod -m 666 ${dev}/tty     c 5 0
      mknod -m 666 ${dev}/ttyS0   c 4 64
      mknod ${dev}/rtc     c 254 0
      ln -s /proc/self/fd /dev/fd
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

    ifconfig lo up

    mkdir /fs

    mount -t tmpfs none /fs

    mkdir -p /fs/dev
    mount -o bind /dev /fs/dev

    mkdir -p /fs/dev/shm /fs/dev/pts
    mount -t tmpfs -o "mode=1777" none /fs/dev/shm
    mount -t devpts none /fs/dev/pts

    echo "mounting Nix store..."
    mkdir -p /fs${storeDir}
    mount -t 9p store /fs${storeDir} -o trans=virtio,version=9p2000.L,cache=loose,aname=${storeDir}

    mkdir -p /fs/tmp /fs/run /fs/var
    mount -t tmpfs -o "mode=1777" none /fs/tmp
    mount -t tmpfs -o "mode=755" none /fs/run
    ln -sfn /run /fs/var/run

    echo "mounting host's temporary directory..."
    mkdir -p /fs/tmp/xchg
    mount -t 9p xchg /fs/tmp/xchg -o trans=virtio,version=9p2000.L,cache=loose,aname="$xchg"

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

  stage2Init = writeScript "vm-run-stage2" ''
    #! ${pkgsLinux.bash}/bin/bash

    export NIX_STORE=${storeDir}
    export NIX_BUILD_TOP=/tmp
    export TMPDIR=/tmp
    cd "$NIX_BUILD_TOP"

    ${pkgsLinux.coreutils}/bin/mkdir -p /bin
    ${pkgsLinux.coreutils}/bin/ln -s ${pkgsLinux.bash}/bin/sh /bin/sh

    echo "root:x:0:0:System administrator:/root:${pkgsLinux.bash}/bin/bash" >> /etc/passwd

    set -x

    echo "loading host's Nix DB..."
    ${pkgsLinux.nix}/bin/nix-store --load-db < /tmp/xchg/nix-db

    echo "realising derivation..."
    ${pkgsLinux.nix}/bin/nix-store --option use-binary-caches false --option build-users-group "" --realise "$drv"
  '';

  img = "bzImage";
  initrd = makeInitrd {
    contents = [
      { object = stage1Init;
        symlink = "/init";
      }
    ];
  };
  buildHook = ''
    #!/bin/sh
    set -x
    # echo $@
    TMPDIR=$(mktemp -d)
    ${diod}/bin/diod -e ${storeDir} -n -l "$TMPDIR/nix-store-9p" -S -f &
    ${diod}/bin/diod -e "$TMPDIR" -n -l "$TMPDIR/xchg-9p" -S -f &
    nix-store --dump-db > "$TMPDIR/nix-db"
    while read amWilling neededSystem drvPath requiredFeatures; do
      echo "# accept" >&2
      read inputs
      read outputs
      # echo "$amWilling"
      # echo "$neededSystem"
      # echo "$drvPath"
      # echo "$requiredFeatures"
      # echo "$inputs"
      # echo "$outputs"
      exec ${hyperkit}/bin/hyperkit \
        -A \
        -s 0,hostbridge \
        -s 1,lpc \
        -s 2,virtio-rnd \
        -s 3,virtio-9p,path=$TMPDIR/nix-store-9p,tag=store \
        -s 4,virtio-9p,path=$TMPDIR/xchg-9p,tag=xchg \
        -l com1,stdio \
        -U ${uuid} \
        -f kexec,${pkgsLinux.linux}/${img},${initrd}/initrd,"console=ttyS0 panic=1 command=${stage2Init} drv=$drvPath xchg=$TMPDIR loglevel=4" \
        $HYPERKIT_ARGS
    done
    kill %1
    kill %2
    rm -r "$TMPDIR"
  '';
in
writeScript "nix-hyperkit-build-hook" buildHook
