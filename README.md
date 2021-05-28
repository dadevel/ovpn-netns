# ovpn-netns

A wrapper around [OpenVPN](https://openvpn.net) with support for Linux network namespaces.
Heavily based on [pekman/openvpn-netns](https://github.com/pekman/openvpn-netns/blob/82342f73ddfef8ca9e4ec7055b0e7a3e39167f1e/openvpn-scripts/netns).

## Setup

Requirements:

- bash
- openvpn
- `ip` from iproute2

Installation:

~~~ bash
git clone --depth 1 https://github.com/dadevel/ovpn-netns.git
sudo ./ovpn-netns/setup.sh
~~~
