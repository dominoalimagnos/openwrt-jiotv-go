#!/bin/sh
# Publish JioTV Go through a Cloudflare Tunnel. Run on the router.
#
#   sh tunnel.sh <tunnel-token>   install cloudflared and connect the tunnel
#   sh tunnel.sh --off            stop and disable the tunnel
#
# Create the tunnel and its public hostname in the Cloudflare dashboard first (see README).

set -e

if [ "$1" = --off ]; then
	uci -q set cloudflared.config.enabled=0 && uci commit cloudflared
	/etc/init.d/cloudflared stop 2>/dev/null || true
	/etc/init.d/cloudflared disable 2>/dev/null || true
	echo "Tunnel disabled."
	exit 0
fi

TOKEN=$1
[ -n "$TOKEN" ] || { sed -n '2,7p' "$0"; exit 1; }

if ! command -v cloudflared >/dev/null; then
	if command -v apk >/dev/null; then
		apk update >/dev/null && apk add cloudflared
	else
		opkg update >/dev/null && opkg install cloudflared
	fi
fi

# restart the tunnel when the uplink comes up; dumb APs have only lan
IFACE=wan
uci -q get network.wan >/dev/null || IFACE=lan

uci set cloudflared.config.enabled=1
uci set cloudflared.config.token="$TOKEN"
uci -q delete cloudflared.config.interfaces || true
uci add_list cloudflared.config.interfaces="$IFACE"
uci commit cloudflared

/etc/init.d/cloudflared enable
/etc/init.d/cloudflared restart

LOG=$(uci -q get cloudflared.config.logfile || echo /var/log/cloudflared.log)
i=0
while [ $i -lt 20 ]; do
	sleep 1
	if grep -q "Registered tunnel connection" "$LOG" 2>/dev/null; then
		echo "Tunnel connected."
		exit 0
	fi
	i=$((i + 1))
done
echo "Tunnel not connected after 20s; check $LOG" >&2
exit 1
