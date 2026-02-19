export PATH=
for i in $initialPath; do
    if [ "$i" = / ]; then i=; fi
    # Translate Windows drive paths (C:/...) to Cygwin format (/cygdrive/c/...)
    case "$i" in [A-Za-z]:/*) i="/cygdrive/${i%%:*}${i#?:}" ;; esac
    PATH=$PATH${PATH:+:}$i/bin
done

mkdir $out

{
    echo "export SHELL=$shell"
    echo "initialPath=\"$initialPath\""
    echo "defaultNativeBuildInputs=\"$defaultNativeBuildInputs\""
    echo "defaultBuildInputs=\"$defaultBuildInputs\""
    echo "$preHook"
    cat "$setup"
} > "$out/setup"

# Allow the user to install stdenv using nix-env and get the packages
# in stdenv.
mkdir $out/nix-support
if [ "${propagatedUserEnvPkgs[*]}" ]; then
    printf '%s ' "${propagatedUserEnvPkgs[@]}" > $out/nix-support/propagated-user-env-packages
fi
