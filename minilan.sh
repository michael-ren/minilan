#!/bin/sh -eu

# Summary:
#   Create a DHCP network, allowing you to connect and exchange files with another device.

# Installation:
#   - Dependencies:
#     - dhcpd
#     - iproute2
#     - coreutils
#     - sudo
#     - jq
#   - Permissions:
#     - If running AppArmor:
#       - install apparmor-utils
#       - sudo aa-complain "$(which dhcpd)"
#     - If running SELinux:
#       - sudo setenforce permissive
#   - Make this file executable

# Running:
#   - ./minilan.sh

# Configuration:
#   - The script will guide you through configuration, but if you would like to change the
#     configuration manually, edit "$CONF_FILE", which contains a json object with the keys:
#     - ip_24: The /24 IP address to use. DHCP clients take the next IP addresses after this one.
#     - interface: The name of the network interface to use.

CONF_FILE=~/.minilan.conf.json
DEFAULT_IP_24=192.168.2.55
DEFAULT_INTERFACE=enp0s25

read_config(){
	# Read $CONF_FILE and set the variables:
	#   - CONFIG_IP_24: The IP address to reach this computer on
	#   - CONFIG_INTERFACE: The network interface to reach this computer by
	#   - CONFIG_IP_24_PREFIX: The network portion of the IP address
	#   - CONFIG_IP_24_HOST: The host portion of the IP address
	#   - CONFIG_IP_24_DHCP_FIRST_CLIENT: The first client host number for DHCP
	#
	# Return:
	#   - 0 on success
        #   - 1 if config file doesn't exist
	#   - 2 if there is something wrong with the config file
	[ -f "$CONF_FILE" ] || return 1

	CONFIG_IP_24="$(jq -r '.ip_24' "$CONF_FILE")"
	[ -z "$(printf '%s' "$CONFIG_IP_24" | tr -d '[:digit:].')" ] || return 2
	[ "3" -eq "$(printf '%s' "$CONFIG_IP_24" | tr -cd '.' | wc -c)" ] || return 2
	[ "7" -le "$(printf '%s' "$CONFIG_IP_24" | wc -c)" ] || return 2
	_OCT_1="$(printf '%s' "$CONFIG_IP_24" | cut -d'.' -f1)"
	_OCT_2="$(printf '%s' "$CONFIG_IP_24" | cut -d'.' -f2)"
	_OCT_3="$(printf '%s' "$CONFIG_IP_24" | cut -d'.' -f3)"
	_OCT_4="$(printf '%s' "$CONFIG_IP_24" | cut -d'.' -f4)"

	[ "$_OCT_1" -ge 1 -a "$_OCT_1" -le 255 ] || return 2
	[ "$_OCT_2" -ge 0 -a "$_OCT_2" -le 255 ] || return 2
	[ "$_OCT_3" -ge 0 -a "$_OCT_3" -le 255 ] || return 2
	[ "$_OCT_4" -ge 1 -a "$_OCT_4" -le 254 ] || return 2

	CONFIG_INTERFACE="$(jq -r '.interface' "$CONF_FILE")"
	[ "$CONFIG_INTERFACE" = "null" ] && return 2

	CONFIG_IP_24_PREFIX="$_OCT_1"."$_OCT_2"."$_OCT_3"
	CONFIG_IP_24_HOST="$_OCT_4"
	CONFIG_IP_24_DHCP_FIRST_CLIENT="$(($CONFIG_IP_24_HOST + 1))"

	return 0
}

setup(){
	# Get configuration from user and write to $CONF_FILE
	printf "%s" "IP address to reach this computer on? [$DEFAULT_IP_24] "
	read INPUT_IP_24
	[ -z "$INPUT_IP_24" ] && INPUT_IP_24="$DEFAULT_IP_24"

	printf "%s" "Network interface to reach this computer by? [$DEFAULT_INTERFACE] "
	read INPUT_INTERFACE
	[ -z "$INPUT_INTERFACE" ] && INPUT_INTERFACE="$DEFAULT_INTERFACE"

	printf '%s' '{}' \
		| jq --arg ip_24 "$INPUT_IP_24" '. + {ip_24: $ip_24}' \
		| jq --arg interface "$INPUT_INTERFACE" '. + {interface: $interface}' \
		> "$CONF_FILE"
}

while true; do
	read_config && break || setup
done

DHCP_LEASE="$(mktemp)"
DHCP_CONF="$(mktemp)"

cleanup(){
	EXIT="$?"
	sudo ip a del "$CONFIG_IP_24"/24 dev "$CONFIG_INTERFACE" || true
	sudo rm -f "$DHCP_LEASE" "${DHCP_LEASE}~" "$DHCP_CONF" || true
	exit "$EXIT"
}

trap cleanup EXIT ABRT INT TERM QUIT HUP

set -x

sudo ip a add "$CONFIG_IP_24"/24 dev "$CONFIG_INTERFACE"

cat <<- EOF > "$DHCP_CONF"
	subnet $CONFIG_IP_24_PREFIX.0 netmask 255.255.255.0 {
	range $CONFIG_IP_24_PREFIX.$CONFIG_IP_24_DHCP_FIRST_CLIENT $CONFIG_IP_24_PREFIX.255;
	}
EOF

sudo dhcpd -f -d -pf /dev/null -lf "$DHCP_LEASE" -cf "$DHCP_CONF" "$CONFIG_INTERFACE"
