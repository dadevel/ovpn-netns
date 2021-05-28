#!/bin/sh
PS4='> '
set -eux

PREFIX="${PREFIX:-/usr/local}"

cd "$(dirname "$0")"
install -m 0755 -D ./ovpn-netns.sh "$PREFIX/bin/ovpn-netns"
install -m 0644 -D ./ovpn-netns@.service "$PREFIX/lib/systemd/system/ovpn-netns@.service"
