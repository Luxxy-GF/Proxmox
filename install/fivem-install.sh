source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os


msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y xz-utils
$STD apt-get install -y jq
$STD apt-get install -y tar
$STD apt-get install -y file
msg_ok "Installed Dependencies"

RELEASE_PAGE=$(curl -sSL https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/)
CHANGELOGS_PAGE=$(curl -sSL https://changelogs-live.fivem.net/api/changelog/versions/linux/server)
FIVEM_VERSION="latest"


if [[ "${FIVEM_VERSION}" == "recommended" ]] || [[ -z ${FIVEM_VERSION} ]]; then
  DOWNLOAD_LINK=$(echo $CHANGELOGS_PAGE | jq -r '.recommended_download')
elif [[ "${FIVEM_VERSION}" == "latest" ]]; then
  DOWNLOAD_LINK=$(echo $CHANGELOGS_PAGE | jq -r '.latest_download')
else
  VERSION_LINK=$(echo -e "${RELEASE_PAGE}" | grep -Eo '".*/*.tar.xz"' | grep -Eo '".*"' | sed 's/\"//g' | sed 's/\.\///1' | grep ${CFX_VERSION})
  if [[ "${VERSION_LINK}" == "" ]]; then
    echo -e "defaulting to recommedned as the version requested was invalid."
    DOWNLOAD_LINK=$(echo $CHANGELOGS_PAGE | jq -r '.recommended_download')
  else
    DOWNLOAD_LINK=$(echo https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/${VERSION_LINK})
  fi
fi
#echo -e "Running curl -sSL ${DOWNLOAD_LINK} -o ${DOWNLOAD_LINK##*/}"
msg_info "Downloading fivem files"
curl -sSL ${DOWNLOAD_LINK} -o ${DOWNLOAD_LINK##*/}
msg_info "Extracting fivem files"
mkdir -p /opt/fivem/
tar -xvf ${DOWNLOAD_LINK##*/} -C /opt/fivem/
rm -rf ${DOWNLOAD_LINK##*/} run.sh
msg_info "install complete"

## create systemd service
msg_info "Creating systemd service"
cat <<EOF >/etc/systemd/system/fivem.service
[Unit]
Description=Fivem Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/fivem/
ExecStart=/opt/fivem/run.sh +exec server.cfg
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
msg_info "systemd service created"
systemctl daemon-reload
systemctl enable fivem.service
systemctl start fivem.service

