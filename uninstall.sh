#!/bin/sh
# Remove JioTV Go from OpenWrt. Run on the router.
#   sh uninstall.sh          keep login + config (/etc/jiotv_go, /etc/config/jiotv_go)
#   sh uninstall.sh --purge  remove those too

if [ -x /etc/init.d/jiotv_go ]; then
	/etc/init.d/jiotv_go stop
	/etc/init.d/jiotv_go disable
fi
rm -f /etc/init.d/jiotv_go /usr/bin/jiotv_go /tmp/jiotv_go /lib/upgrade/keep.d/jiotv_go
rm -rf /usr/libexec/jiotv_go

if [ "$1" = --purge ]; then
	rm -rf /etc/jiotv_go /etc/config/jiotv_go
	echo "JioTV Go removed, including login and config."
else
	echo "JioTV Go removed. Login and config kept; use --purge to delete them."
fi
