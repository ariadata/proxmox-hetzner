#!/bin/sh
set -e
clear

curl -L "https://github.com/ariadata/proxmox-hetzner/raw/main/files/main_vmbr0_basic_template.txt" -o ~/interfaces_sample
IFACE_NAME="$(udevadm info -e | grep -m1 -A 20 ^P.*eth0 | grep ID_NET_NAME_PATH | cut -d'=' -f2)"
MAIN_IPV4_CIDR="$(ip address show ${IFACE_NAME} | grep global | grep "inet "| xargs | cut -d" " -f2)"
MAIN_IPV4_GW="$(ip route | grep default | xargs | cut -d" " -f3)"
MAIN_IPV6_CIDR="$(ip address show ${IFACE_NAME} | grep global | grep "inet6 "| xargs | cut -d" " -f2)"
MAIN_MAC_ADDR="$(ifconfig eth0 | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')"

sed -i "s|#IFACE_NAME#|$IFACE_NAME|g" ~/interfaces_sample
sed -i "s|#MAIN_IPV4_CIDR#|$MAIN_IPV4_CIDR|g" ~/interfaces_sample
sed -i "s|#MAIN_IPV4_GW#|$MAIN_IPV4_GW|g" ~/interfaces_sample
sed -i "s|#MAIN_MAC_ADDR#|$MAIN_MAC_ADDR|g" ~/interfaces_sample
sed -i "s|#MAIN_IPV6_CIDR#|$MAIN_IPV6_CIDR|g" ~/interfaces_sample

scp -P 5555 ~/interfaces_sample root@127.0.0.1:/etc/network/interfaces

# echo "\nmain configuration for vmbr0 is done!"
