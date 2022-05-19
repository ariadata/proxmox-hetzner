## Install Basic Proxmox on Debian in Hetzner Dedicated Servers
[![Build Status](https://files.ariadata.co/file/ariadata_logo.png)](https://ariadata.co)

![](https://img.shields.io/github/stars/ariadata/proxmox-hetzner.svg)
![](https://img.shields.io/github/watchers/ariadata/proxmox-hetzner.svg)
![](https://img.shields.io/github/forks/ariadata/proxmox-hetzner.svg)
---
#### 1- Prepare the rescue from hetzner robot :
* Select the Rescue tab for the specific server, via the hetzner robot manager
* * Operating system=Linux
* * Architecture=64 bit
* * Public key=*optional*
* --> Activate rescue system
* Select the Reset tab for the specific server,
* Check: Execute an automatic hardware reset
* --> Send
* Wait a few mins
* Connect via ssh/terminal to the rescue system running on your server
#### 2- Install Debian with Raid-1 :
```sh
installimage -l 1
# Make sure to do right partition
reboot
# Wait 5 minutes then Login (again) with SSH to server
```
#### 3- Config for hostname and timezone :
```sh
hostnamectl set-hostname proxmox-example
timedatectl set-timezone Europe/Istanbul
```
#### 4- Do some Basic Configs :
```sh
echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bullseye pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription-repo.list
curl -L "https://enterprise.proxmox.com/debian/proxmox-release-bullseye.gpg" -o /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg
apt update && apt upgrade -y
systemctl disable --now rpcbind rpcbind.socket
sed -i "s|Debian-.*|$(hostname)|g" /etc/hosts
printf "nameserver 1.1.1.1\nnameserver 2606:4700:4700::1111\n" > /etc/resolv.conf
apt install -y proxmox-ve open-iscsi libguestfs-tools unzip iptables-persistent
printf "net.ipv4.ip_forward=1\nnet.ipv6.conf.all.forwarding=1\n" >> /etc/sysctl.congf
sysctl -p
sed -i 's/^\([^#].*\)/# \1/g' /etc/apt/sources.list.d/pve-enterprise.list
pveupgrade
sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js && systemctl restart pveproxy.service
netfilter-persistent reload
```
#### 5- Change ssh port:
```sh
bash <(curl -Ls https://gist.github.com/pcmehrdad/2fbc9651a6cff249f0576b784fdadef0/raw)
```
#### 6- Change root password , then `reboot`:
```sh
passwd
reboot
```
#### 7- Login to `Web GUI`:
https://IP_ADDRESS:8006/
#### 9- Do other configs!:
....
#### Useful Links :
```
https://github.com/extremeshok/xshok-proxmox
https://github.com/extremeshok/xshok-proxmox/tree/master/hetzner
https://88plug.com/linux/what-to-do-after-you-install-proxmox/
https://gist.github.com/gushmazuko/9208438b7be6ac4e6476529385047bbb
https://github.com/johnknott/proxmox-hetzner-autoconfigure
https://github.com/CasCas2/proxmox-hetzner
https://github.com/west17m/hetzner-proxmox
https://github.com/SOlangsam/hetzner-proxmox-nat
https://github.com/HoleInTheSeat/ProxmoxStater
https://github.com/rloyaute/proxmox-iptables-hetzner
```

[Useful Helpers](https://tteck.github.io/Proxmox/)
