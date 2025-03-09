## Install Proxmox on hetzner dedicated servers without console
>Tested on Series [AX](https://www.hetzner.com/dedicated-rootserver/matrix-ax) , [EX](https://www.hetzner.com/dedicated-rootserver/matrix-ex) , [SX](https://www.hetzner.com/dedicated-rootserver/matrix-sx)

<img src="https://github.com/ariadata/proxmox-hetzner/raw/main/files/icons/proxmox.png" alt="Proxmox" height="48" /> <img src="https://github.com/ariadata/proxmox-hetzner/raw/main/files/icons/hetzner.png" alt="Hetzner" height="38" /> 

![](https://img.shields.io/github/stars/ariadata/proxmox-hetzner.svg)
![](https://img.shields.io/github/watchers/ariadata/proxmox-hetzner.svg)
![](https://img.shields.io/github/forks/ariadata/proxmox-hetzner.svg)
---
## Steps :
* [Prepare and Boot into rescue mode](#prepare-and-boot-into-rescue-mode)
* [Start installing with auto-installer](#start-installing)
* [Do some post install scripts/commands](#run-some-post-install-scriptscommands)
* [Your server is ready!](#your-server-is-ready-to-use)
* [Useful links](#useful-links)



### 1- Prepare the rescue from hetzner robot manager
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


## 2- Start installation:
Just run this command in rescue bash:
```bash
bash <(curl -sSL https://github.com/ariadata/proxmox-hetzner/raw/main/scripts/pve-install.sh)
```


## 3- Run some optional post install commands
* Just run this command in rescue bash! (optional)
```shell
# In pve bash :
apt update && apt -y upgrade && apt -y autoremove && pveupgrade && pveam update

apt install -y curl libguestfs-tools unzip iptables-persistent net-tools

sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js && systemctl restart pveproxy.service

```

* Limit ZFS Memory Usage According to [This Link](https://pve.proxmox.com/wiki/ZFS_on_Linux#sysadmin_zfs_limit_memory_usage) :
```bash
# In pve bash :
echo "nf_conntrack" >> /etc/modules
echo "net.netfilter.nf_conntrack_max=1048576" >> /etc/sysctl.d/99-proxmox.conf
echo "net.netfilter.nf_conntrack_tcp_timeout_established=28800" >> /etc/sysctl.d/99-proxmox.conf
rm -f /etc/modprobe.d/zfs.conf
echo "options zfs zfs_arc_min=$[6 * 1024*1024*1024]" >> /etc/modprobe.d/99-zfs.conf
echo "options zfs zfs_arc_max=$[12 * 1024*1024*1024]" >> /etc/modprobe.d/99-zfs.conf
update-initramfs -u
```

## 4- Your server is ready to use
* Login to `Web GUI` on port `8006` with `root` user and password that you entered during install promxox.
    > https://Your-Server-IP:8006

* Your could use `notes.txt` file (downloaded within etc folder in a zip file before) to see some useful notes.



## Useful links
[ReadMe-v1.md](https://github.com/ariadata/proxmox-hetzner/blob/main/README-v1.md)

[ReadMe-v2.md](https://github.com/ariadata/proxmox-hetzner/blob/main/README-v2.md)

### Other Links :
```
https://tteck.github.io/Proxmox/
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
https://computingforgeeks.com/how-to-install-and-configure-firewalld-on-debian/
https://www.virtualizationhowto.com/2022/10/proxmox-firewall-rules-configuration/
```
