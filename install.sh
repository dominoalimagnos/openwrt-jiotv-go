#!/bin/sh
# Install or upgrade JioTV Go as a procd service on OpenWrt. Run on the router.
#
#   sh install.sh [-v VERSION] [-m auto|flash|ram] [-p PORT]
#
#   -v  release tag, e.g. v3.22.0 (default: latest)
#   -m  flash = binary in /usr/bin, ram = binary in /tmp (re-downloaded at boot),
#       auto  = flash when there is room for it plus 10 MB headroom (default)
#   -p  listen port (default: keep current, else 5001)

set -e

REPO=jiotv-go/jiotv_go
VERSION=latest
MODE=auto
PORT=
HEADROOM_KB=10240
HERE=$(cd "$(dirname "$0")" && pwd)

die() { echo "error: $*" >&2; exit 1; }

while getopts "v:m:p:h" opt; do
	case $opt in
		v) VERSION=$OPTARG ;;
		m) MODE=$OPTARG ;;
		p) PORT=$OPTARG ;;
		*) sed -n '2,10p' "$0"; exit 0 ;;
	esac
done

case $MODE in auto|flash|ram) ;; *) die "mode must be auto, flash or ram" ;; esac
[ -f /etc/openwrt_release ] || die "this does not look like OpenWrt"
[ -f "$HERE/files/jiotv_go.init" ] || die "run from the repo checkout (files/ not found)"

case $(uname -m) in
	aarch64|arm64) ARCH=arm64 ;;
	armv5*|armv6*|armv7*) ARCH=arm ;;
	x86_64) ARCH=amd64 ;;
	i?86) ARCH=386 ;;
	riscv64) ARCH=riscv64 ;;
	*) die "no JioTV Go build for $(uname -m) (MIPS routers are not supported upstream)" ;;
esac

if [ "$VERSION" = latest ]; then
	VERSION=$(wget -qO- "https://api.github.com/repos/$REPO/releases/latest" |
		sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1)
	[ -n "$VERSION" ] || die "could not resolve latest release (check WAN, DNS and ca-bundle)"
fi
URL="https://github.com/$REPO/releases/download/$VERSION/jiotv_go-linux-$ARCH"

echo "Downloading $VERSION for linux-$ARCH ..."
TMP=/tmp/jiotv_go.download
wget -q -O "$TMP" "$URL" || { rm -f "$TMP"; die "download failed: $URL"; }
chmod +x "$TMP"
"$TMP" --version >/dev/null 2>&1 || { rm -f "$TMP"; die "downloaded binary does not run on this device"; }
SIZE_KB=$(( $(wc -c < "$TMP") / 1024 ))

if [ "$MODE" = auto ]; then
	FREE_KB=$(df -k /overlay 2>/dev/null | awk 'NR==2 {print $4}')
	[ -n "$FREE_KB" ] || FREE_KB=$(df -k / | awk 'NR==2 {print $4}')
	# when upgrading in place the old binary's space comes back
	[ -f /usr/bin/jiotv_go ] && FREE_KB=$(( FREE_KB + $(wc -c < /usr/bin/jiotv_go) / 1024 ))
	if [ "$FREE_KB" -ge $(( SIZE_KB + HEADROOM_KB )) ]; then MODE=flash; else MODE=ram; fi
	echo "Flash free: ${FREE_KB} KB, binary: ${SIZE_KB} KB -> $MODE install"
fi

[ -x /etc/init.d/jiotv_go ] && /etc/init.d/jiotv_go stop 2>/dev/null || true

if [ "$MODE" = flash ]; then
	BIN=/usr/bin/jiotv_go
	rm -f /tmp/jiotv_go
else
	BIN=/tmp/jiotv_go
	rm -f /usr/bin/jiotv_go
fi
mv "$TMP" "$BIN"

mkdir -p /usr/libexec/jiotv_go /lib/upgrade/keep.d
cp "$HERE/files/run.sh" /usr/libexec/jiotv_go/run.sh
cp "$HERE/files/jiotv_go.init" /etc/init.d/jiotv_go
chmod +x /usr/libexec/jiotv_go/run.sh /etc/init.d/jiotv_go
# keep the config across installs so the login and user tweaks survive
[ -f /etc/config/jiotv_go ] || cp "$HERE/files/jiotv_go.config" /etc/config/jiotv_go
printf '/etc/config/jiotv_go\n/etc/jiotv_go/\n' > /lib/upgrade/keep.d/jiotv_go

uci set jiotv_go.main.bin="$BIN"
uci set jiotv_go.main.url="$URL"
[ -n "$PORT" ] && uci set jiotv_go.main.port="$PORT"
uci commit jiotv_go

/etc/init.d/jiotv_go enable
/etc/init.d/jiotv_go stop >/dev/null 2>&1 || true
/etc/init.d/jiotv_go start

PORT=$(uci -q get jiotv_go.main.port || echo 5001)
LAN_IP=$(uci -q get network.lan.ipaddr | cut -d/ -f1)
sleep 3
if netstat -tln 2>/dev/null | grep -q ":$PORT "; then
	echo "JioTV Go $VERSION is running ($MODE install)."
else
	echo "Service started but not listening yet; check: logread -e jiotv_go"
fi
echo "  Web UI / login: http://${LAN_IP:-<router-ip>}:$PORT"
echo "  Playlist:       http://${LAN_IP:-<router-ip>}:$PORT/playlist.m3u"
