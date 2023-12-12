#!/bin/sh

REPO='https://github.com/LiterMC/go-openbmclapi'
BASE_PATH=/opt/openbmclapi


if [ $(id -u) -ne 0 ]; then
	read -p 'ERROR: You are not root user, are you sure to continue?(y/N) ' Y
	echo
	[ "$Y" = "Y" ] || [ "$Y" = "y" ] || exit 1
fi

if ! systemd --version; then
	echo "ERROR: Failed to test systemd"
	exit 1
fi

if [ ! -d /usr/lib/systemd/system/ ]; then
	echo 'ERROR: /usr/lib/systemd/system/ are not exist'
	exit 1
fi

function fetchGithubLatestTag(){
	prefix="location: $REPO/releases/tag/"
	location=$(curl -sSI "$REPO/releases/latest" | grep "$prefix")
	[ $? = 0 ] || return 1
	export LATEST_TAG="${location#${prefix}}"
}

function fetchBlob(){
	file=$1
	target=$2
	filemod=$3

	source="$REPO/blob/$LATEST_TAG/$file"
	echo "==> Downloading $source"
	tmpf=$(mktemp -t go-openbmclapi.XXXXXXXXXXXX.downloading)
	curl -sSL -o "$tmpf" "$source" || { rm "$tmpf"; return 1; }
	echo "==> Downloaded $source"
	mv "$tmpf" "$target" || return $?
	[ -n "$filemod" ] || chmod "$filemod" "$target" || return $?
}

if [ -f /usr/lib/systemd/system/go-openbmclapi.service ]; then
	echo 'WARN: go-openbmclapi.service is already installed, disabled'
	systemctl disable go-openbmclapi.service
fi

echo "==> Fetching latest tag for $REPO"
fetchGithubLatestTag
echo "go-openbmclapi LATEST TAG: $LATEST_TAG"
echo

fetchBlob service/go-openbmclapi.service /usr/lib/systemd/system/go-openbmclapi.service 0644

[ -d "$BASE_PATH" ] || { mkdir -p /opt/openbmclapi && chmod 0755 "$BASE_PATH"; } || exit $?

fetchBlob service/start-server.sh "$BASE_PATH/start-server.sh" 0744 || exit $?
fetchBlob service/stop-server.sh "$BASE_PATH/stop-server.sh" 0744 || exit $?
fetchBlob service/reload-server.sh "$BASE_PATH/reload-server.sh" 0744 || exit $?


arch=$(uname -m)
source="$REPO/releases/download/$LATEST_TAG/go-opembmclapi-linux-$arch"
echo "==> Downloading $source"
if ! curl -L -o ./service-linux-go-openbmclapi "$source"; then
	source="$REPO/releases/download/$LATEST_TAG/go-opembmclapi-linux-amd64"
	echo "==> Downloading fallback binary $source"
	curl -L -o "$BASE_PATH/service-linux-go-openbmclapi" "$source" || exit $?
fi
chmod 0744 "$BASE_PATH/service-linux-go-openbmclapi" || exit $?


echo "==> Enable go-openbmclapi.service"
systemctl enable go-openbmclapi.service || exit $?

echo "
================================ Install successed ================================

  Use 'systemctl start go-openbmclapi.service' to start openbmclapi server
  Use 'systemctl stop go-openbmclapi.service' to stop openbmclapi server
  Use 'systemctl reload go-openbmclapi.service' to reload openbmclapi server configs
  Use 'journalctl -f -u go-openbmclapi.service' to watch the openbmclapi logs
"
