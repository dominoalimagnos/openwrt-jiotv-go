#!/bin/sh
# Push this repo to a router over SSH and run a script there. Run from your computer.
#
#   ./deploy.sh root@192.168.1.100 [install.sh options]   install / upgrade
#   ./deploy.sh root@192.168.1.100 --tunnel <token>       connect a Cloudflare Tunnel
#   ./deploy.sh root@192.168.1.100 --tunnel --off         disconnect it
#   ./deploy.sh root@192.168.1.100 --uninstall [--purge]  remove
#
# Uses tar over ssh, so it works with Dropbear routers that have no sftp server.

set -e
TARGET=$1
[ -n "$TARGET" ] || { sed -n '2,8p' "$0"; exit 1; }
shift

SCRIPT=install.sh
case $1 in
	--uninstall) SCRIPT=uninstall.sh; shift ;;
	--tunnel) SCRIPT=tunnel.sh; shift ;;
esac

cd "$(dirname "$0")"
COPYFILE_DISABLE=1 tar -cf - install.sh uninstall.sh tunnel.sh files |
	ssh "$TARGET" "rm -rf /tmp/openwrt-jiotv-go && mkdir -p /tmp/openwrt-jiotv-go && tar -xf - -C /tmp/openwrt-jiotv-go && sh /tmp/openwrt-jiotv-go/$SCRIPT $*"
