#!/usr/bin/env bash

# Copyright (c) 2021-2023 tteck
# Author: tteck (tteckster)
#         Jon Spriggs (jontheniceguy)
# License: MIT
# https://github.com/Luxxy-GF/Proxmox/raw/main/LICENSE
# Based on work from https://i12bretro.github.io/tutorials/0405.html

function header_info {
  clear
  cat <<"EOF"
   ____                 _       __     __
  / __ \____  ___  ____| |     / /____/ /_
 / / / / __ \/ _ \/ __ \ | /| / / ___/ __/
/ /_/ / /_/ /  __/ / / / |/ |/ / /  / /_
\____/ .___/\___/_/ /_/|__/|__/_/   \__/
    /_/ W I R E L E S S   F R E E D O M

EOF
}
header_info
echo -e "Loading..."
GEN_MAC=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
GEN_MAC_LAN=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
NEXTID=$(pvesh get /cluster/nextid)
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
HA=$(echo "\033[1;34m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
set -Eeuo pipefail
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
trap cleanup EXIT
function error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  echo -e "\n$error_message\n"
  cleanup_vmid
}

function cleanup_vmid() {
  if qm status $VMID &>/dev/null; then
    qm stop $VMID &>/dev/null
    qm destroy $VMID &>/dev/null
  fi
}

function cleanup() {
  popd >/dev/null
  rm -rf $TEMP_DIR
}

TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null
function send_line_to_vm() {
  echo -e "${DGN}Sending line: ${YW}$1${CL}"
  for ((i = 0; i < ${#1}; i++)); do
    character=${1:i:1}
    case $character in
    " ") character="spc" ;;
    "-") character="minus" ;;
    "=") character="equal" ;;
    ",") character="comma" ;;
    ".") character="dot" ;;
    "/") character="slash" ;;
    "'") character="apostrophe" ;;
    ";") character="semicolon" ;;
    '\') character="backslash" ;;
    '`') character="grave_accent" ;;
    "[") character="bracket_left" ;;
    "]") character="bracket_right" ;;
    "_") character="shift-minus" ;;
    "+") character="shift-equal" ;;
    "?") character="shift-slash" ;;
    "<") character="shift-comma" ;;
    ">") character="shift-dot" ;;
    '"') character="shift-apostrophe" ;;
    ":") character="shift-semicolon" ;;
    "|") character="shift-backslash" ;;
    "~") character="shift-grave_accent" ;;
    "{") character="shift-bracket_left" ;;
    "}") character="shift-bracket_right" ;;
    "A") character="shift-a" ;;
    "B") character="shift-b" ;;
    "C") character="shift-c" ;;
    "D") character="shift-d" ;;
    "E") character="shift-e" ;;
    "F") character="shift-f" ;;
    "G") character="shift-g" ;;
    "H") character="shift-h" ;;
    "I") character="shift-i" ;;
    "J") character="shift-j" ;;
    "K") character="shift-k" ;;
    "L") character="shift-l" ;;
    "M") character="shift-m" ;;
    "N") character="shift-n" ;;
    "O") character="shift-o" ;;
    "P") character="shift-p" ;;
    "Q") character="shift-q" ;;
    "R") character="shift-r" ;;
    "S") character="shift-s" ;;
    "T") character="shift-t" ;;
    "U") character="shift-u" ;;
    "V") character="shift-v" ;;
    "W") character="shift-w" ;;
    "X") character="shift=x" ;;
    "Y") character="shift-y" ;;
    "Z") character="shift-z" ;;
    "!") character="shift-1" ;;
    "@") character="shift-2" ;;
    "#") character="shift-3" ;;
    '$') character="shift-4" ;;
    "%") character="shift-5" ;;
    "^") character="shift-6" ;;
    "&") character="shift-7" ;;
    "*") character="shift-8" ;;
    "(") character="shift-9" ;;
    ")") character="shift-0" ;;
    esac
    qm sendkey $VMID "$character"
  done
  qm sendkey $VMID ret
}

TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null

if (whiptail --title "OpenWrt VM" --yesno "This will create a New OpenWrt VM. Proceed?" 10 58); then
  :
else
  header_info && echo -e "⚠ User exited script \n" && exit
fi

function msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

function pve_check() {
  if [ $(pveversion | grep -c "pve-manager/7\.[2-9]") -eq 0 ]; then
    echo -e "${CROSS} This version of Proxmox Virtual Environment is not supported"
    echo -e "Requires PVE Version 7.2 or higher"
    echo -e "Exiting..."
    sleep 2
    exit
  fi
}

function arch_check() {
  if [ "$(dpkg --print-architecture)" != "amd64" ]; then
    echo -e "\n ${CROSS} This script will not work with PiMox! \n"
    echo -e "Exiting..."
    sleep 2
    exit
  fi
}

function ssh_check() {
  if command -v pveversion >/dev/null 2>&1; then
    if [ -n "${SSH_CLIENT:+x}" ]; then
      if whiptail --defaultno --title "SSH DETECTED" --yesno "It's suggested to use the Proxmox shell instead of SSH, since SSH can create issues while gathering variables. Would you like to proceed with using SSH?" 10 62; then
        echo "you've been warned"
      else
        clear
        exit
      fi
    fi
  fi
}

function exit-script() {
  clear
  echo -e "⚠  User exited script \n"
  exit
}

function default_settings() {
  VMID=$NEXTID
  HN=openwrt
  CORE_COUNT="1"
  RAM_SIZE="256"
  BRG="vmbr0"
  VLAN=""
  MAC=$GEN_MAC
  LAN_MAC=$GEN_MAC_LAN
  LAN_BRG="vmbr0"
  LAN_VLAN=",tag=999"
  MTU=""
  START_VM="yes"
  echo -e "${DGN}Using Virtual Machine ID: ${BGN}${VMID}${CL}"
  echo -e "${DGN}Using Hostname: ${BGN}${HN}${CL}"
  echo -e "${DGN}Allocated Cores: ${BGN}${CORE_COUNT}${CL}"
  echo -e "${DGN}Allocated RAM: ${BGN}${RAM_SIZE}${CL}"
  echo -e "${DGN}Using WAN Bridge: ${BGN}${BRG}${CL}"
  echo -e "${DGN}Using WAN VLAN: ${BGN}Default${CL}"
  echo -e "${DGN}Using WAN MAC Address: ${BGN}${MAC}${CL}"
  echo -e "${DGN}Using LAN MAC Address: ${BGN}${LAN_MAC}${CL}"
  echo -e "${DGN}Using LAN Bridge: ${BGN}${LAN_BRG}${CL}"
  echo -e "${DGN}Using LAN VLAN: ${BGN}999${CL}"
  echo -e "${DGN}Using Interface MTU Size: ${BGN}Default${CL}"
  echo -e "${DGN}Start VM when completed: ${BGN}yes${CL}"
  echo -e "${BL}Creating a OpenWRT VM using the above default settings${CL}"
}

function advanced_settings() {
  while true; do
    if VMID=$(whiptail --inputbox "Set Virtual Machine ID" 8 58 $NEXTID --title "VIRTUAL MACHINE ID" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
      if [ -z "$VMID" ]; then
        VMID="$NEXTID"
      fi
      if pct status "$VMID" &>/dev/null || qm status "$VMID" &>/dev/null; then
        echo -e "${CROSS}${RD} ID $VMID is already in use${CL}"
        sleep 2
        continue
      fi
      echo -e "${DGN}Virtual Machine ID: ${BGN}$VMID${CL}"
      break
    else
      exit-script
    fi
  done

  if VM_NAME=$(whiptail --inputbox "Set Hostname" 8 58 openwrt --title "HOSTNAME" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VM_NAME ]; then
      HN="openwrt"
      echo -e "${DGN}Using Hostname: ${BGN}$HN${CL}"
    else
      HN=$(echo ${VM_NAME,,} | tr -d ' ')
      echo -e "${DGN}Using Hostname: ${BGN}$HN${CL}"
    fi
  else
    exit-script
  fi

  if CORE_COUNT=$(whiptail --inputbox "Allocate CPU Cores" 8 58 1 --title "CORE COUNT" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $CORE_COUNT ]; then
      CORE_COUNT="1"
      echo -e "${DGN}Allocated Cores: ${BGN}$CORE_COUNT${CL}"
    else
      echo -e "${DGN}Allocated Cores: ${BGN}$CORE_COUNT${CL}"
    fi
  else
    exit-script
  fi

  if RAM_SIZE=$(whiptail --inputbox "Allocate RAM in MiB" 8 58 256 --title "RAM" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $RAM_SIZE ]; then
      RAM_SIZE="256"
      echo -e "${DGN}Allocated RAM: ${BGN}$RAM_SIZE${CL}"
    else
      echo -e "${DGN}Allocated RAM: ${BGN}$RAM_SIZE${CL}"
    fi
  else
    exit-script
  fi

  if BRG=$(whiptail --inputbox "Set a WAN Bridge" 8 58 vmbr0 --title "WAN BRIDGE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $BRG ]; then
      BRG="vmbr0"
      echo -e "${DGN}Using WAN Bridge: ${BGN}$BRG${CL}"
    else
      echo -e "${DGN}Using WAN Bridge: ${BGN}$BRG${CL}"
    fi
  else
    exit-script
  fi

  if LAN_BRG=$(whiptail --inputbox "Set a LAN Bridge" 8 58 vmbr0 --title "LAN BRIDGE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $LAN_BRG ]; then
      LAN_BRG="vmbr0"
      echo -e "${DGN}Using LAN Bridge: ${BGN}$LAN_BRG${CL}"
    else
      echo -e "${DGN}Using LAN Bridge: ${BGN}$LAN_BRG${CL}"
    fi
  else
    exit-script
  fi

  if MAC1=$(whiptail --inputbox "Set a WAN MAC Address" 8 58 $GEN_MAC --title "WAN MAC ADDRESS" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $MAC1 ]; then
      MAC="$GEN_MAC"
      echo -e "${DGN}Using WAN MAC Address: ${BGN}$MAC${CL}"
    else
      MAC="$MAC1"
      echo -e "${DGN}Using WAN MAC Address: ${BGN}$MAC1${CL}"
    fi
  else
    exit-script
  fi

  if MAC2=$(whiptail --inputbox "Set a LAN MAC Address" 8 58 $GEN_MAC_LAN --title "LAN MAC ADDRESS" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $MAC2 ]; then
      LAN_MAC="$GEN_MAC_LAN"
      echo -e "${DGN}Using LAN MAC Address: ${BGN}$LAN_MAC${CL}"
    else
      LAN_MAC="$MAC2"
      echo -e "${DGN}Using LAN MAC Address: ${BGN}$MAC2${CL}"
    fi
  else
    exit-script
  fi

  if VLAN1=$(whiptail --inputbox "Set a Vlan(leave blank for default)" 8 58 --title "WAN VLAN" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VLAN1 ]; then
      VLAN1="Default"
      VLAN=""
      echo -e "${DGN}Using WAN Vlan: ${BGN}$VLAN1${CL}"
    else
      VLAN=",tag=$VLAN1"
      echo -e "${DGN}Using WAN Vlan: ${BGN}$VLAN1${CL}"
    fi
  else
    exit-script
  fi

  if VLAN2=$(whiptail --inputbox "Set a LAN Vlan" 8 58 999 --title "LAN VLAN" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VLAN2 ]; then
      VLAN2="999"
      LAN_VLAN=",tag=$VLAN2"
      echo -e "${DGN}Using LAN Vlan: ${BGN}$VLAN2${CL}"
    else
      LAN_VLAN=",tag=$VLAN2"
      echo -e "${DGN}Using LAN Vlan: ${BGN}$VLAN2${CL}"
    fi
  else
    exit-script
  fi

  if MTU1=$(whiptail --inputbox "Set Interface MTU Size (leave blank for default)" 8 58 --title "MTU SIZE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $MTU1 ]; then
      MTU1="Default"
      MTU=""
      echo -e "${DGN}Using Interface MTU Size: ${BGN}$MTU1${CL}"
    else
      MTU=",mtu=$MTU1"
      echo -e "${DGN}Using Interface MTU Size: ${BGN}$MTU1${CL}"
    fi
  else
    exit-script
  fi

  if (whiptail --title "START VIRTUAL MACHINE" --yesno "Start VM when completed?" 10 58); then
    echo -e "${DGN}Start VM when completed: ${BGN}yes${CL}"
    START_VM="yes"
  else
    echo -e "${DGN}Start VM when completed: ${BGN}no${CL}"
    START_VM="no"
  fi

  if (whiptail --title "ADVANCED SETTINGS COMPLETE" --yesno "Ready to create OpenWrt VM?" --no-button Do-Over 10 58); then
    echo -e "${RD}Creating a OpenWrt VM using the above advanced settings${CL}"
  else
    header_info
    echo -e "${RD}Using Advanced Settings${CL}"
    advanced_settings
  fi
}

function start_script() {
  if (whiptail --title "SETTINGS" --yesno "Use Default Settings?" --no-button Advanced 10 58); then
    header_info
    echo -e "${BL}Using Default Settings${CL}"
    default_settings
  else
    header_info
    echo -e "${RD}Using Advanced Settings${CL}"
    advanced_settings
  fi
}

arch_check
pve_check
ssh_check
start_script

msg_info "Validating Storage"
while read -r line; do
  TAG=$(echo $line | awk '{print $1}')
  TYPE=$(echo $line | awk '{printf "%-10s", $2}')
  FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
  ITEM="  Type: $TYPE Free: $FREE "
  OFFSET=2
  if [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]]; then
    MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
  fi
  STORAGE_MENU+=("$TAG" "$ITEM" "OFF")
done < <(pvesm status -content images | awk 'NR>1')
VALID=$(pvesm status -content images | awk 'NR>1')
if [ -z "$VALID" ]; then
  echo -e "\n${RD}⚠ Unable to detect a valid storage location.${CL}"
  echo -e "Exiting..."
  exit
elif [ $((${#STORAGE_MENU[@]} / 3)) -eq 1 ]; then
  STORAGE=${STORAGE_MENU[0]}
else
  while [ -z "${STORAGE:+x}" ]; do
    STORAGE=$(whiptail --title "Storage Pools" --radiolist \
      "Which storage pool you would like to use for the OpenWrt VM?\n\n" \
      16 $(($MSG_MAX_LENGTH + 23)) 6 \
      "${STORAGE_MENU[@]}" 3>&1 1>&2 2>&3) || exit
  done
fi
msg_ok "Using ${CL}${BL}$STORAGE${CL} ${GN}for Storage Location."
msg_ok "Virtual Machine ID is ${CL}${BL}$VMID${CL}."
msg_info "Getting URL for OpenWrt Disk Image"

regex='<strong>Current Stable Release - OpenWrt ([^/]*)<\/strong>' && response=$(curl -s https://openwrt.org) && [[ $response =~ $regex ]] && stableVersion="${BASH_REMATCH[1]}"
URL=https://downloads.openwrt.org/releases/$stableVersion/targets/x86/64/openwrt-$stableVersion-x86-64-generic-ext4-combined.img.gz

sleep 2
msg_ok "${CL}${BL}${URL}${CL}"
wget -q --show-progress $URL
echo -en "\e[1A\e[0K"
FILE=$(basename $URL)
msg_ok "Downloaded ${CL}${BL}$FILE${CL}"
gunzip -f $FILE >/dev/null 2>/dev/null || true
NEWFILE="${FILE%.*}"
FILE="$NEWFILE"
mv $FILE ${FILE%.*}
qemu-img resize -f raw ${FILE%.*} 512M >/dev/null 2>/dev/null
msg_ok "Extracted & Resized OpenWrt Disk Image ${CL}${BL}$FILE${CL}"
STORAGE_TYPE=$(pvesm status -storage $STORAGE | awk 'NR>1 {print $2}')
case $STORAGE_TYPE in
nfs | dir)
  DISK_EXT=".qcow2"
  DISK_REF="$VMID/"
  DISK_IMPORT="-format qcow2"
  ;;
btrfs)
  DISK_EXT=".raw"
  DISK_REF="$VMID/"
  DISK_IMPORT="-format raw"
  ;;
esac
for i in {0,1}; do
  disk="DISK$i"
  eval DISK${i}=vm-${VMID}-disk-${i}${DISK_EXT:-}
  eval DISK${i}_REF=${STORAGE}:${DISK_REF:-}${!disk}
done

msg_info "Creating OpenWrt VM"
qm create $VMID -cores $CORE_COUNT -memory $RAM_SIZE -name $HN \
  -onboot 1 -ostype l26 -scsihw virtio-scsi-pci --tablet 0
pvesm alloc $STORAGE $VMID $DISK0 4M 1>&/dev/null
qm importdisk $VMID ${FILE%.*} $STORAGE ${DISK_IMPORT:-} 1>&/dev/null
qm set $VMID \
  -efidisk0 ${DISK0_REF},efitype=4m,size=4M \
  -scsi0 ${DISK1_REF},size=512M \
  -boot order=scsi0 \
  -description "# OpenWrt VM
### https://github.com/Luxxy-GF/Proxmox
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/D1D7EP4GF)" >/dev/null
msg_ok "OpenWrt VM ${CL}${BL}(${HN})"
msg_info "OpenWrt is being started in order to configure the network interfaces."
qm start $VMID
sleep 15
msg_ok "Network interfaces are being configured as OpenWrt initiates."
send_line_to_vm ""
send_line_to_vm "uci delete network.@device[0]"
send_line_to_vm "uci set network.wan=interface"
send_line_to_vm "uci set network.wan.device=eth0"
send_line_to_vm "uci set network.wan.proto=dhcp"
send_line_to_vm "uci delete network.lan"
send_line_to_vm "uci set network.lan=interface"
send_line_to_vm "uci set network.lan.device=eth1"
send_line_to_vm "uci set network.lan.proto=static"
send_line_to_vm "uci set network.lan.ipaddr=192.0.2.1"
send_line_to_vm "uci set network.lan.netmask=255.255.255.0"
send_line_to_vm "uci set firewall.@zone[1].input='ACCEPT'"
send_line_to_vm "uci set firewall.@zone[1].forward='ACCEPT'"
send_line_to_vm "uci commit"
send_line_to_vm "halt"
msg_ok "Network interfaces have been successfully configured."
until qm status $VMID | grep -q "stopped"; do
  sleep 2
done
msg_info "Bridge interfaces are being added."
qm set $VMID \
  -net0 virtio,bridge=${BRG},macaddr=${MAC}${VLAN}${MTU} \
  -net1 virtio,bridge=${LAN_BRG},macaddr=${LAN_MAC}${LAN_VLAN}${MTU} >/dev/null 2>/dev/null
msg_ok "Bridge interfaces have been successfully added."
if [ "$START_VM" == "yes" ]; then
  msg_info "Starting OpenWrt VM"
  qm start $VMID
  msg_ok "Started OpenWrt VM"
fi
VLAN_FINISH=""
if [ "$VLAN" == "" ] && [ "$VLAN2" != "999" ]; then
  VLAN_FINISH=" Please remember to adjust the VLAN tags to suit your network."
fi
msg_ok "Completed Successfully!\n${VLAN_FINISH}"
