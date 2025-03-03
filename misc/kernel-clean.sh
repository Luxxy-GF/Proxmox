#!/usr/bin/env bash

# Copyright (c) 2021-2023 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/Luxxy-GF/Proxmox/raw/main/LICENSE

function header_info {
    cat <<"EOF"
    __ __                     __   ________               
   / //_/__  _________  ___  / /  / ____/ /__  ____ _____
  / ,< / _ \/ ___/ __ \/ _ \/ /  / /   / / _ \/ __ `/ __ \
 / /| /  __/ /  / / / /  __/ /  / /___/ /  __/ /_/ / / / /
/_/ |_\___/_/  /_/ /_/\___/_/   \____/_/\___/\__,_/_/ /_/

EOF
}
set -euo pipefail
shopt -s inherit_errexit nullglob
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
PARTY="🎉"
current_kernel=$(uname -r)
clear
header_info
while true; do
    read -p "This will Clean Unused Kernel Images, USE AT YOUR OWN RISK. Proceed(y/n)?" yn
    case $yn in
    [Yy]*) break ;;
    [Nn]*) exit ;;
    *) echo -e "${RD}Please answer y/n${CL}" ;;
    esac
done
clear
function msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
    local msg="$1"
    echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${CROSS}${RD}Error: This script must be ran as the root user.\n${CL}"
        exit 1
    else
        header_info
        other_kernel
        kernel_info
        kernel_clean
    fi
}

function other_kernel() {
    if [[ "$current_kernel" == *"edge"* ]]; then
        echo -e "\n${CROSS} ${RD}ERROR:${CL} Proxmox ${BL}${current_kernel}${CL} Kernel Active"
        echo -e "\nAn Active PVE Kernel is required to use Kernel Clean\n"
        exit 1
    fi
    if [[ "$current_kernel" == *"6.1"* || "$current_kernel" == *"6.2"* ]]; then
        echo -e "\n${CROSS} ${RD}ERROR:${CL} Proxmox ${BL}${current_kernel}${CL} Kernel Active"
        echo -e "\nThe script cannot be used when running opt-in kernels. \nProxmox VE's package management relies directly on the current default kernel, which is 5.15. \nTherefore, it is not possible to utilize this script. In this case, you should use autoremove instead. \n`apt-get autoremove`\n"
        exit 1
    fi
}

function kernel_info() {
    if [[ "$MODE" != "PBS" ]]; then
        echo -e "${YW}PVE Version: ${BL}$(pveversion)\n${CL}"
    fi
    if [[ "$current_kernel" == *"pve"* ]]; then
        echo -e "${YW}Current Kernel: ${BL}$current_kernel\n${CL}"
    else
        echo -e "\n${CROSS} ${RD}ERROR: No PVE Kernel Found\n${CL}"
        exit 1
    fi
}

function kernel_clean() {
    kernels=$(dpkg --list | grep 'kernel-.*-pve' | awk '{print $2}' | sort -V)
    remove_kernels=""
    for kernel in $kernels; do
        if [ "$(echo $kernel | grep $current_kernel)" ]; then
            break
        else
            echo -e "${BL}'$kernel' ${CL}${YW}has been added to the remove Kernel list\n${CL}"
            remove_kernels+=" $kernel"
        fi
    done
    msg_ok "Kernel Search Completed\n"
    if [[ "$remove_kernels" != *"pve"* ]]; then
        echo -e "${PARTY}  ${GN}It appears there are no old Kernels on your system. \n${CL}"
        msg_info "Exiting"
        sleep 2
        msg_ok "Done"
    else
        read -p "Would you like to remove the $(echo $remove_kernels | awk '{print NF}') selected Kernels listed above? [y/n]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            msg_info "Removing ${CL}${RD}$(echo $remove_kernels | awk '{print NF}') ${CL}${YW}old Kernels${CL}"
            /usr/bin/apt purge -y $remove_kernels >/dev/null 2>&1
            msg_ok "Successfully Removed Kernels"
            msg_info "Updating GRUB"
            /usr/sbin/update-grub >/dev/null 2>&1
            msg_ok "Successfully Updated GRUB"
            msg_info "Exiting"
            sleep 2
            msg_ok "Done"
        else
            msg_info "Exiting"
            sleep 2
            msg_ok "Done"
        fi
    fi
}

if ! command -v pveversion >/dev/null 2>&1; then
    echo -e " Switching to PBS mode"
    MODE="PBS"
    sleep 2
else
    MODE="PVE"
fi

check_root
