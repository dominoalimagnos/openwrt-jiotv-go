#!/bin/sh
# Usage: run.sh <binary> <download-url> <jiotv_go args...>
# Fetches the binary if it is missing (RAM install after a reboot), then execs it.

BIN="$1"
URL="$2"
shift 2

if [ ! -x "$BIN" ]; then
	[ -n "$URL" ] || { echo "jiotv_go: $BIN missing and no url configured" >&2; exit 1; }
	mkdir -p "$(dirname "$BIN")"
	until wget -q -O "$BIN.part" "$URL"; do
		echo "jiotv_go: download failed, retrying in 30s" >&2
		rm -f "$BIN.part"
		sleep 30
	done
	mv "$BIN.part" "$BIN"
	chmod +x "$BIN"
fi

exec "$BIN" "$@"
