source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os


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
echo -e "Running curl -sSL ${DOWNLOAD_LINK} -o ${DOWNLOAD_LINK##*/}"
curl -sSL ${DOWNLOAD_LINK} -o ${DOWNLOAD_LINK##*/}
echo "Extracting fivem files"
tar -xvf ${DOWNLOAD_LINK##*/} -C /opt/fivem/
rm -rf ${DOWNLOAD_LINK##*/} run.sh
echo "install complete"

## create systemd service
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
systemctl daemon-reload
systemctl enable fivem.service
systemctl start fivem.service

