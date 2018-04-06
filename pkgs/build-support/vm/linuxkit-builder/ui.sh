#!@bash@/bin/bash -eu

BOOT_FILES=@boot_files@
HOST_PORT=@hostPort
INTEGRATED_PATH=@integrated_path@
EXAMPLE_PATH=@example_path@
VPNKIT_ROOT=@vpnkit@
HYPERKIT_ROOT=@hyperkit@
LINUXKIT_ROOT=@linuxkit@
CONTAINER_IP=@containerIp@

usage() {
  echo "Usage: $(basename "$0") [-d directory] [-f features] [-s size] [-c cpus] [-m mem]" >&2
}

NAME="linuxkit-builder"

DIR="$HOME/.nixpkgs/$NAME"
FEATURES="big-parallel"
SIZE="10G"
CPUS=1
MEM=1024
while getopts "d:f:s:c:m:h" opt; do
  case $opt in
    d) DIR="$OPTARG" ;;
    f) FEATURES="$OPTARG" ;;
    s) SIZE="$OPTARG" ;;
    c) CPUS="$OPTARG" ;;
    m) MEM="$OPTARG" ;;
    h | \?)
      usage
      exit 64
      ;;
  esac
done

mkdir -p "$DIR"

if [ ! -d "$DIR/keys" ]; then
  mkdir -p "$DIR/keys"
  (
    cd "$DIR/keys"
    ssh-keygen -C "Nix LinuxKit Builder, Client" -N "" -f client
    ssh-keygen -C "Nix LinuxKit Builder, Server" -f ssh_host_ecdsa_key -N "" -t ecdsa

    tar -cf server-config.tar client.pub ssh_host_ecdsa_key.pub ssh_host_ecdsa_key

    echo -n "[localhost]:$HOST_PORT " > known_host
    cat ssh_host_ecdsa_key.pub >> known_host
  )
fi

cp "$INTEGRATED_PATH" "$DIR/integrated.sh"
chmod +x "$DIR/integrated.sh"
cp "$EXAMPLE_PATH" "$DIR/example.nix"

cat <<EOF > "$DIR/ssh-config"
Host nix-linuxkit
   HostName localhost
   User root
   Port $HOST_PORT
   IdentityFile $DIR/keys/client
   StrictHostKeyChecking yes
   UserKnownHostsFile $DIR/keys/known_host
   IdentitiesOnly yes
EOF


cat <<-EOF > "$DIR/finish-setup.sh"
  #!/bin/sh
  cat <<EOI
  1. Add the following to /etc/nix/machines:

    nix-linuxkit x86_64-linux $DIR/keys/client $CPUS 1 $FEATURES

  2. Add the following to /var/root/.ssh/config:

    Host nix-linuxkit
       HostName localhost
       User root
       Port $HOST_PORT
       IdentityFile $DIR/keys/client
       StrictHostKeyChecking yes
       UserKnownHostsFile $DIR/keys/known_host
       IdentitiesOnly yes

  3. Try it out!

    nix-build $DIR/example.nix


EOF

chmod +x "$DIR/finish-setup.sh"

PATH="$VPNKIT_ROOT/bin:$PATH"
exec "$LINUXKIT_ROOT/bin/linuxkit" run \
  hyperkit \
  -hyperkit "$HYPERKIT_ROOT/bin/hyperkit" "$@" \
  -networking vpnkit \
  -ip "$CONTAINER_IP" \
  -disk "$DIR/nix-disk,size=$SIZE" \
  -data-file "$DIR/keys/server-config.tar" \
  -cpus "$CPUS" \
  -mem "$MEM" \
  -state "$DIR/nix-state" \
  "$BOOT_FILES/nix"
