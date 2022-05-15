#!/bin/bash

echo 'deb http://ftp.debian.org/debian buster-backports main' >> /etc/apt/sources.list.d/buster-backports.list
apt update && apt install wireguard linux-headers-$(uname -r) -y

umask 077
wg genkey | tee /etc/wireguard/server-private.key | wg pubkey > /etc/wireguard/server-public.key
wg genkey | tee /etc/wireguard/client-private.key | wg pubkey > /etc/wireguard/client-public.key

cat <<EOF > /etc/wireguard/wg0.conf
[Interface]
Address = 10.0.10.1/24
SaveConfig = true
PostUp = sysctl -w net.ipv4.ip_forward=1
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ens4 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ens4 -j MASQUERADE
ListenPort = 51820
PrivateKey = $(cat /etc/wireguard/server-private.key)

[Peer]
PublicKey = $(cat /etc/wireguard/client-public.key)
AllowedIPs = 10.0.10.2/32
EOF

wg-quick up wg0
systemctl enable wg-quick@wg0.service
