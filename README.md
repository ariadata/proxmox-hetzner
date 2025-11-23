# Proxmox on Hetzner Without Console Access

<div align="center">
  <img src="https://github.com/payk24/proxmox-hetzner/raw/main/files/icons/proxmox.png" alt="Proxmox" height="64" /> 
  <img src="https://github.com/payk24/proxmox-hetzner/raw/main/files/icons/hetzner.png" alt="Hetzner" height="50" />
  <h3>Automated Installation for Hetzner Dedicated Servers</h3>
  
  ![GitHub Stars](https://img.shields.io/github/stars/payk24/proxmox-hetzner.svg)
  ![GitHub Watchers](https://img.shields.io/github/watchers/payk24/proxmox-hetzner.svg)
  ![GitHub Forks](https://img.shields.io/github/forks/payk24/proxmox-hetzner.svg)
</div>

## 📑 Overview

This project provides an automated solution for installing Proxmox VE on Hetzner dedicated servers **without requiring console access**. It streamlines the installation process using a custom script that handles all the complex configuration steps automatically.

**Compatible Hetzner Server Series:**
- [AX Series](https://www.hetzner.com/dedicated-rootserver/matrix-ax)
- [EX Series](https://www.hetzner.com/dedicated-rootserver/matrix-ex)
- [SX Series](https://www.hetzner.com/dedicated-rootserver/matrix-sx)

> ⚠️ **Note:** This script has been primarily tested on AX-102 servers and configures disks in RAID-1 (ZFS) format.

<div align="center">
  <br>
  <h3>❤️ Love This Tool? ❤️</h3>
  <p>If this project has saved you time and effort, please consider starring it!</p>
  <p>
    <a href="https://github.com/payk24/proxmox-hetzner" target="_blank">
      <img src="https://img.shields.io/github/stars/payk24/proxmox-hetzner?style=social" alt="Star on GitHub">
    </a>
  </p>
  <p><b>Every star motivates me to create more awesome tools for the community!</b></p>
  <br>
</div>

## 🚀 Installation Process

### 1. Prepare Rescue Mode

1. Access the Hetzner Robot Manager for your server
2. Navigate to the **Rescue** tab and configure:
   - Operating system: **Linux**
   - Architecture: **64 bit**
   - Public key: *optional*
3. Click **Activate rescue system**
4. Go to the **Reset** tab
5. Check: **Execute an automatic hardware reset**
6. Click **Send**
7. Wait a few minutes for the server to boot into rescue mode
8. Connect via SSH to the rescue system

### 2. Run Installation Script

Execute this single command in the rescue system terminal:

```bash
bash <(curl -sSL https://github.com/payk24/proxmox-hetzner/raw/main/scripts/pve-install.sh)
```

The script will:
- Download the latest Proxmox VE ISO
- Create an auto-installation configuration
- Install Proxmox VE with RAID-1 ZFS configuration
- Configure networking for both IPv4 and IPv6
- Set up proper hostname and FQDN
- Apply recommended system settings

### 3. Optional Post-Installation Optimizations

Run these commands in your Proxmox environment for additional optimizations:

```bash
# Update system packages
apt update && apt -y upgrade && apt -y autoremove && pveupgrade && pveam update

# Install useful utilities
apt install -y curl libguestfs-tools unzip iptables-persistent net-tools

# Remove subscription notice
sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js && systemctl restart pveproxy.service
```

#### Optimize ZFS Memory Usage

```bash
# Configure ZFS memory limits
echo "nf_conntrack" >> /etc/modules
echo "net.netfilter.nf_conntrack_max=1048576" >> /etc/sysctl.d/99-proxmox.conf
echo "net.netfilter.nf_conntrack_tcp_timeout_established=28800" >> /etc/sysctl.d/99-proxmox.conf
rm -f /etc/modprobe.d/zfs.conf
echo "options zfs zfs_arc_min=$[6 * 1024*1024*1024]" >> /etc/modprobe.d/99-zfs.conf
echo "options zfs zfs_arc_max=$[12 * 1024*1024*1024]" >> /etc/modprobe.d/99-zfs.conf
update-initramfs -u
```

## ✅ Accessing Your Proxmox Server

After installation completes:

1. Access the Proxmox Web GUI: `https://YOUR-SERVER-IP:8006`
2. Login with:
   - Username: `root`
   - Password: *the password you set during installation*

> You can also refer to the `notes.txt` file (downloaded during installation) for additional useful information.

## 📚 Additional Resources

### Project Documentation
- [ReadMe-v1.md](https://github.com/payk24/proxmox-hetzner/blob/main/README-v1.md)
- [ReadMe-v2.md](https://github.com/payk24/proxmox-hetzner/blob/main/README-v2.md)

### Related Resources
- [tteck's Proxmox Helper Scripts](https://tteck.github.io/Proxmox/)
- [extremeshok's Proxmox Tools](https://github.com/extremeshok/xshok-proxmox)
- [Hetzner-specific Proxmox Tools](https://github.com/extremeshok/xshok-proxmox/tree/master/hetzner)
- [Proxmox Post-Installation Guide](https://88plug.com/linux/what-to-do-after-you-install-proxmox/)
- [Proxmox Subscription Notice Removal](https://gist.github.com/gushmazuko/9208438b7be6ac4e6476529385047bbb)
- [Proxmox Hetzner Autoconfiguration](https://github.com/johnknott/proxmox-hetzner-autoconfigure)
- [Alternative Proxmox Hetzner Setup](https://github.com/CasCas2/proxmox-hetzner)
- [Hetzner Proxmox Configuration](https://github.com/west17m/hetzner-proxmox)
- [Hetzner Proxmox NAT Setup](https://github.com/SOlangsam/hetzner-proxmox-nat)
- [Proxmox Starter Guide](https://github.com/HoleInTheSeat/ProxmoxStater)
- [Proxmox IPTables for Hetzner](https://github.com/rloyaute/proxmox-iptables-hetzner)
- [Firewalld on Debian Guide](https://computingforgeeks.com/how-to-install-and-configure-firewalld-on-debian/)
- [Proxmox Firewall Configuration Guide](https://www.virtualizationhowto.com/2022/10/proxmox-firewall-rules-configuration/)

## License

This project is licensed under the [MIT License](LICENSE).