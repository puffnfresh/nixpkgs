#!/bin/sh

set -eux

exec ssh -F $(dirname "$0")/ssh-config nix-linuxkit nix-daemon --stdio
