#!/usr/bin/bash
set -e
cd /root

# Define colors for output
CLR_RED="\033[1;31m"
CLR_GREEN="\033[1;32m"
CLR_YELLOW="\033[1;33m"
CLR_BLUE="\033[1;34m"
CLR_RESET="\033[m"

clear

# Ensure the script is run as root
if [[ $EUID != 0 ]]; then
    echo -e "${CLR_RED}Please run this script as root.${CLR_RESET}"
    exit 1
fi

echo -e "${CLR_GREEN}Starting Proxmox auto-installation...${CLR_RESET}"

# Function to get system information
get_system_info() {
    INTERFACE_NAME=$(udevadm info -e | grep -m1 -A 20 ^P.*eth0 | grep ID_NET_NAME_PATH | cut -d'=' -f2)
    MAIN_IPV4_CIDR=$(ip address show "$INTERFACE_NAME" | grep global | grep "inet " | xargs | cut -d" " -f2)
    MAIN_IPV4=$(echo "$MAIN_IPV4_CIDR" | cut -d'/' -f1)
    MAIN_IPV4_GW=$(ip route | grep default | xargs | cut -d" " -f3)
    MAC_ADDRESS=$(ip link show "$INTERFACE_NAME" | awk '/ether/ {print $2}')
    IPV6_CIDR=$(ip address show "$INTERFACE_NAME" | grep global | grep "inet6 " | xargs | cut -d" " -f2)
    MAIN_IPV6=$(echo "$IPV6_CIDR" | cut -d'/' -f1)

    FIRST_IPV6_CIDR="$(echo "$IPV6_CIDR" | cut -d'/' -f1 | cut -d':' -f1-4):1::1/80"

    echo -e "${CLR_YELLOW}Detected System Information:${CLR_RESET}"
    echo "Interface Name: $INTERFACE_NAME"
    echo "Main IPv4 CIDR: $MAIN_IPV4_CIDR"
    echo "Main IPv4: $MAIN_IPV4"
    echo "Main IPv4 Gateway: $MAIN_IPV4_GW"
    echo "MAC Address: $MAC_ADDRESS"
    echo "IPv6 CIDR: $IPV6_CIDR"
    echo "IPv6: $MAIN_IPV6"
    echo "First IPv6: $FIRST_IPV6_CIDR"
}

# Function to get user input
get_user_input() {
    read -e -p "Enter your hostname : " -i "proxmox-example" HOSTNAME
    read -e -p "Enter your FQDN name : " -i "proxmox.example.com" FQDN
    read -e -p "Enter your timezone : " -i "Europe/Istanbul" TIMEZONE
    read -e -p "Enter your email address: " -i "admin@example.com" EMAIL
    read -e -p "Enter your private subnet : " -i "192.168.26.0/24" PRIVATE_SUBNET
    read -e -p "Enter your System New root password: " NEW_ROOT_PASSWORD
    
    # Get the network prefix (first three octets) from PRIVATE_SUBNET
    PRIVATE_CIDR=$(echo "$PRIVATE_SUBNET" | cut -d'/' -f1 | rev | cut -d'.' -f2- | rev)
    # Append .1 to get the first IP in the subnet
    PRIVATE_IP="${PRIVATE_CIDR}.1"
    # Get the subnet mask length
    SUBNET_MASK=$(echo "$PRIVATE_SUBNET" | cut -d'/' -f2)
    # Create the full CIDR notation for the first IP
    PRIVATE_IP_CIDR="${PRIVATE_IP}/${SUBNET_MASK}"
    
    # Check password was not empty, do it in loop until password is not empty
    while [[ -z "$NEW_ROOT_PASSWORD" ]]; do
        # Print message in a new line
        echo ""
        read -e -p "Enter your System New root password: " NEW_ROOT_PASSWORD
    done

    echo ""
    echo "Private subnet: $PRIVATE_SUBNET"
    echo "First IP in subnet (CIDR): $PRIVATE_IP_CIDR"
}


prepare_packages() {
    echo -e "${CLR_BLUE}Installing packages...${CLR_RESET}"
    echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" | tee /etc/apt/sources.list.d/pve.list
    curl -o /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg
    apt clean && apt update && apt install -yq proxmox-auto-install-assistant xorriso ovmf wget sshpass

    echo -e "${CLR_GREEN}Packages installed.${CLR_RESET}"
}

# Fetch latest Proxmox VE ISO
get_latest_proxmox_ve_iso() {
    local base_url="https://enterprise.proxmox.com/iso/"
    local latest_iso=$(curl -s "$base_url" | grep -oP 'proxmox-ve_[0-9]+\.[0-9]+-[0-9]+\.iso' | sort -V | tail -n1)

    if [[ -n "$latest_iso" ]]; then
        echo "${base_url}${latest_iso}"
    else
        echo "No Proxmox VE ISO found." >&2
        return 1
    fi
}

download_proxmox_iso() {
    echo -e "${CLR_BLUE}Downloading Proxmox ISO...${CLR_RESET}"
    PROXMOX_ISO_URL=$(get_latest_proxmox_ve_iso)
    if [[ -z "$PROXMOX_ISO_URL" ]]; then
        echo -e "${CLR_RED}Failed to retrieve Proxmox ISO URL! Exiting.${CLR_RESET}"
        exit 1
    fi
    wget -O pve.iso "$PROXMOX_ISO_URL"
    echo -e "${CLR_GREEN}Proxmox ISO downloaded.${CLR_RESET}"
}

make_answer_toml() {
    echo -e "${CLR_BLUE}Making answer.toml...${CLR_RESET}"
    cat <<EOF > answer.toml
[global]
    keyboard = "en-us"
    country = "us"
    fqdn = "$FQDN"
    mailto = "$EMAIL"
    timezone = "$TIMEZONE"
    root_password = "$NEW_ROOT_PASSWORD"
    reboot_on_error = false

[network]
    source = "from-dhcp"

[disk-setup]
    filesystem = "zfs"
    zfs.raid = "raid1"
    disk_list = ["/dev/vda", "/dev/vdb"]

EOF
    echo -e "${CLR_GREEN}answer.toml created.${CLR_RESET}"
}

make_autoinstall_iso() {
    echo -e "${CLR_BLUE}Making autoinstall.iso...${CLR_RESET}"
    proxmox-auto-install-assistant prepare-iso pve.iso --fetch-from iso --answer-file answer.toml --output pve-autoinstall.iso
    echo -e "${CLR_GREEN}pve-autoinstall.iso created.${CLR_RESET}"
}

is_uefi_mode() {
  [ -d /sys/firmware/efi ]
}

# Install Proxmox via QEMU/VNC
install_proxmox() {
    echo -e "${CLR_GREEN}Starting Proxmox VE installation...${CLR_RESET}"

    if is_uefi_mode; then
        UEFI_OPTS="-bios /usr/share/ovmf/OVMF.fd"
        echo -e "UEFI Supported! Booting with UEFI firmware."
    else
        UEFI_OPTS=""
        echo -e "UEFI Not Supported! Booting in legacy mode."
    fi
    echo -e "${CLR_YELLOW}Installing Proxmox VE${CLR_RESET}"
	echo -e "${CLR_YELLOW}=================================${CLR_RESET}"
    echo -e "${CLR_RED}Do not do anything, just wait about 2-5 min!${CLR_RED}"
	echo -e "${CLR_YELLOW}=================================${CLR_RESET}"
    #UEFI_OPTS=""

    printf "change vnc password\n%s\n" "abcd_123456" | qemu-system-x86_64 \
        -enable-kvm $UEFI_OPTS \
        -cpu host -smp 4 -m 4096 \
        -boot d -cdrom ./pve-autoinstall.iso \
        -drive file=/dev/nvme0n1,format=raw,media=disk,if=virtio \
        -drive file=/dev/nvme1n1,format=raw,media=disk,if=virtio \
        -vnc :0,password=on -monitor stdio -no-reboot
}

# Function to boot the installed Proxmox via QEMU with port forwarding
boot_proxmox_with_port_forwarding() {
    echo -e "${CLR_GREEN}Booting installed Proxmox with SSH port forwarding...${CLR_RESET}"

    if is_uefi_mode; then
        UEFI_OPTS="-bios /usr/share/ovmf/OVMF.fd"
        echo -e "${CLR_YELLOW}UEFI Supported! Booting with UEFI firmware.${CLR_RESET}"
    else
        UEFI_OPTS=""
        echo -e "${CLR_YELLOW}UEFI Not Supported! Booting in legacy mode.${CLR_RESET}"
    fi
    # UEFI_OPTS=""
    # Start QEMU in background with port forwarding
    nohup qemu-system-x86_64 -enable-kvm $UEFI_OPTS \
        -cpu host -device e1000,netdev=net0 \
        -netdev user,id=net0,hostfwd=tcp::5555-:22 \
        -smp 4 -m 4096 \
        -drive file=/dev/nvme0n1,format=raw,media=disk,if=virtio \
        -drive file=/dev/nvme1n1,format=raw,media=disk,if=virtio \
        > qemu_output.log 2>&1 &
    
    QEMU_PID=$!
    echo -e "${CLR_YELLOW}QEMU started with PID: $QEMU_PID${CLR_RESET}"
    
    # Wait for SSH to become available on port 5555
    echo -e "${CLR_YELLOW}Waiting for SSH to become available on port 5555...${CLR_RESET}"
    for i in {1..60}; do
        if nc -z localhost 5555; then
            echo -e "${CLR_GREEN}SSH is available on port 5555.${CLR_RESET}"
            break
        fi
        echo -n "."
        sleep 5
        if [ $i -eq 60 ]; then
            echo -e "${CLR_RED}SSH is not available after 5 minutes. Check the system manually.${CLR_RESET}"
            return 1
        fi
    done
    
    return 0
}

make_template_files() {
    echo -e "${CLR_BLUE}Modifying template files...${CLR_RESET}"
    
    echo -e "${CLR_YELLOW}Downloading template files...${CLR_RESET}"
    mkdir -p ./template_files

    wget -O ./template_files/99-proxmox.conf https://github.com/ariadata/proxmox-hetzner/raw/refs/heads/main/files/template_files/99-proxmox.conf
    wget -O ./template_files/hosts https://github.com/ariadata/proxmox-hetzner/raw/refs/heads/main/files/template_files/hosts
    wget -O ./template_files/interfaces https://github.com/ariadata/proxmox-hetzner/raw/refs/heads/main/files/template_files/interfaces
    wget -O ./template_files/sources.list https://github.com/ariadata/proxmox-hetzner/raw/refs/heads/main/files/template_files/sources.list

    # Process hosts file
    echo -e "${CLR_YELLOW}Processing hosts file...${CLR_RESET}"
    sed -i "s|{{MAIN_IPV4}}|$MAIN_IPV4|g" ./template_files/hosts
    sed -i "s|{{FQDN}}|$FQDN|g" ./template_files/hosts
    sed -i "s|{{HOSTNAME}}|$HOSTNAME|g" ./template_files/hosts
    sed -i "s|{{MAIN_IPV6}}|$MAIN_IPV6|g" ./template_files/hosts

    # Process interfaces file
    echo -e "${CLR_YELLOW}Processing interfaces file...${CLR_RESET}"
    sed -i "s|{{INTERFACE_NAME}}|$INTERFACE_NAME|g" ./template_files/interfaces
    sed -i "s|{{MAIN_IPV4_CIDR}}|$MAIN_IPV4_CIDR|g" ./template_files/interfaces
    sed -i "s|{{MAIN_IPV4_GW}}|$MAIN_IPV4_GW|g" ./template_files/interfaces
    sed -i "s|{{MAC_ADDRESS}}|$MAC_ADDRESS|g" ./template_files/interfaces
    sed -i "s|{{IPV6_CIDR}}|$IPV6_CIDR|g" ./template_files/interfaces
    sed -i "s|{{PRIVATE_IP_CIDR}}|$PRIVATE_IP_CIDR|g" ./template_files/interfaces
    sed -i "s|{{PRIVATE_SUBNET}}|$PRIVATE_SUBNET|g" ./template_files/interfaces
    sed -i "s|{{FIRST_IPV6_CIDR}}|$FIRST_IPV6_CIDR|g" ./template_files/interfaces

    echo -e "${CLR_GREEN}Template files modified successfully.${CLR_RESET}"
}

# Function to configure the installed Proxmox via SSH
configure_proxmox_via_ssh() {
    echo -e "${CLR_BLUE}Starting post-installation configuration via SSH...${CLR_RESET}"
    make_template_files
	ssh-keygen -f "/root/.ssh/known_hosts" -R "[localhost]:5555"
    # copy template files to the server using scp
    sshpass -p "$NEW_ROOT_PASSWORD" scp -P 5555 -o StrictHostKeyChecking=no template_files/hosts root@localhost:/etc/hosts
    sshpass -p "$NEW_ROOT_PASSWORD" scp -P 5555 -o StrictHostKeyChecking=no template_files/interfaces root@localhost:/etc/network/interfaces
    sshpass -p "$NEW_ROOT_PASSWORD" scp -P 5555 -o StrictHostKeyChecking=no template_files/99-proxmox.conf root@localhost:/etc/sysctl.d/99-proxmox.conf
    sshpass -p "$NEW_ROOT_PASSWORD" scp -P 5555 -o StrictHostKeyChecking=no template_files/sources.list root@localhost:/etc/apt/sources.list
    
    # comment out the line in the sources.list file
    sshpass -p "$NEW_ROOT_PASSWORD" ssh -p 5555 -o StrictHostKeyChecking=no root@localhost "sed -i 's/^\([^#].*\)/# \1/g' /etc/apt/sources.list.d/pve-enterprise.list"
    sshpass -p "$NEW_ROOT_PASSWORD" ssh -p 5555 -o StrictHostKeyChecking=no root@localhost "sed -i 's/^\([^#].*\)/# \1/g' /etc/apt/sources.list.d/ceph.list"
    sshpass -p "$NEW_ROOT_PASSWORD" ssh -p 5555 -o StrictHostKeyChecking=no root@localhost "echo -e 'nameserver 8.8.8.8\nnameserver 1.1.1.1\nnameserver 4.2.2.4\nnameserver 9.9.9.9' | tee /etc/resolv.conf"
    sshpass -p "$NEW_ROOT_PASSWORD" ssh -p 5555 -o StrictHostKeyChecking=no root@localhost "echo $HOSTNAME > /etc/hostname"
    sshpass -p "$NEW_ROOT_PASSWORD" ssh -p 5555 -o StrictHostKeyChecking=no root@localhost "systemctl disable --now rpcbind rpcbind.socket"
    # Power off the VM
    echo -e "${CLR_YELLOW}Powering off the VM...${CLR_RESET}"
    sshpass -p "$NEW_ROOT_PASSWORD" ssh -p 5555 -o StrictHostKeyChecking=no root@localhost 'poweroff' || true
    
    # Wait for QEMU to exit
    echo -e "${CLR_YELLOW}Waiting for QEMU process to exit...${CLR_RESET}"
    wait $QEMU_PID || true
    echo -e "${CLR_GREEN}QEMU process has exited.${CLR_RESET}"
}

# Function to reboot into the main OS
reboot_to_main_os() {
    echo -e "${CLR_GREEN}Installation complete!${CLR_RESET}"
    echo -e "${CLR_YELLOW}After rebooting, you will be able to access your Proxmox at https://${MAIN_IPV4_CIDR%/*}:8006${CLR_RESET}"
    
    #ask user to reboot the system
    read -e -p "Do you want to reboot the system? (y/n): " -i "y" REBOOT
    if [[ "$REBOOT" == "y" ]]; then
        echo -e "${CLR_YELLOW}Rebooting the system...${CLR_RESET}"
        reboot
    else
        echo -e "${CLR_YELLOW}Exiting...${CLR_RESET}"
        exit 0
    fi
}



# Main execution flow
# Main execution flow
get_system_info
get_user_input
prepare_packages
download_proxmox_iso
make_answer_toml
make_autoinstall_iso
install_proxmox

echo -e "${CLR_YELLOW}Waiting for installation to complete...${CLR_RESET}"

# Boot the installed Proxmox with port forwarding
boot_proxmox_with_port_forwarding || {
    echo -e "${CLR_RED}Failed to boot Proxmox with port forwarding. Exiting.${CLR_RESET}"
    exit 1
}

# Configure Proxmox via SSH
configure_proxmox_via_ssh

# Reboot to the main OS
reboot_to_main_os