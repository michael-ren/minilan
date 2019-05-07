# Minilan

Create a local DHCP network on the fly, e.g. for file sharing

## Installation

Minilan requires `dhcpd`, `iproute2`, `coreutils`, `sudo`, and `jq`.

If AppArmor is enabled, install `apparmor-utils` and run:

    sudo aa-complain "$(which dhcpd)"

If SELinux is enabled, run:

    sudo setenforce permissive

Make `minilan.sh` executable and optionally copy it to somewhere on `$PATH`, e.g. `/usr/local/bin/minilan`.

## Running

If running from same directory:

    ./minilan.sh

If copied onto `$PATH`:

    minilan

The first time, `minilan` will ask for an IP address to reach your machine at on the LAN and the network interface to create the LAN on. Make sure those two values are what you want them to be, otherwise edit them manually afterwards inside the generated `~/.minilan.conf.json` config file.
