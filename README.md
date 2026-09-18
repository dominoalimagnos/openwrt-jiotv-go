# openwrt-jiotv-go

Run [JioTV Go](https://jiotv_go.rabil.me) as a proper OpenWrt service: procd-managed, configured through UCI, starts at boot, restarts if it crashes, and keeps your Jio login across reboots and sysupgrades.

## Requirements

- OpenWrt with `wget` able to reach HTTPS (the default `uclient-fetch` + `ca-bundle` work)
- CPU: aarch64, armv5–7, x86_64, i386 or riscv64. MIPS has no upstream build.
- About 18 MB of flash for the binary, or none in RAM mode (see below)
- About 40 MB RAM while running
- An Indian IP on the router's WAN, because Jio geo-blocks playback

## Install

From your computer, pointed at the router's SSH:

```sh
./deploy.sh root@192.168.1.100
```

That copies the repo over SSH (tar, so Dropbear without sftp is fine), downloads the latest release for the router's CPU, installs the service and starts it. Re-run the same command to upgrade; your config and login are kept.

Options go after the target:

```sh
./deploy.sh root@192.168.1.100 -v v3.22.0   # pin a release
./deploy.sh root@192.168.1.100 -m ram       # force RAM mode
./deploy.sh root@192.168.1.100 -p 8080      # different port
./deploy.sh root@192.168.1.100 --uninstall          # remove, keep login
./deploy.sh root@192.168.1.100 --uninstall --purge  # remove everything
```

If the repo is already on the router, run `sh install.sh [options]` there instead.

### Flash vs RAM mode

`-m auto` (the default) picks flash when there is room for the binary plus 10 MB headroom, and RAM otherwise.

| Mode | Binary lives in | After a reboot |
|---|---|---|
| flash | `/usr/bin/jiotv_go` | starts immediately |
| ram | `/tmp/jiotv_go` | re-downloaded at boot (retries every 30 s until WAN is up), then starts |

In both modes, the login is stored on flash in `/etc/jiotv_go`. It is only a few hundred bytes.

## First login

Open `http://<router-ip>:5001` and sign in with your Jio number and OTP. You only do this once.

## Use

| What | URL |
|---|---|
| Web player | `http://<router-ip>:5001` |
| M3U playlist (VLC, TiviMate, OTT Navigator, Kodi…) | `http://<router-ip>:5001/playlist.m3u` |

## Configuration

Edit `/etc/config/jiotv_go`, then `service jiotv_go restart`:

| Option | Default | Meaning |
|---|---|---|
| `enabled` | `1` | start the service |
| `host` | `0.0.0.0` | listen address |
| `port` | `5001` | listen port |
| `path_prefix` | `/etc/jiotv_go` | login and settings (flash) |
| `log_path` | `/tmp/log/jiotv_go` | request log (RAM, because it logs every request) |
| `epg` | `0` | build the TV guide. Writes several MB into `path_prefix`, so it is off by default to spare flash |
| `drm` | `1` | DRM channels |
| `disable_logout` | `1` | hide the logout button so a viewer can't log you out |
| `title` | `JioTV Go` | page title |
| `bin`, `url` | set by installer | binary path and its download URL |

Logs: `cat /tmp/log/jiotv_go/jiotv_go.log` or `logread -e jiotv_go`.

## Watching away from home

JioTV Go has **no password**. Anyone who can reach the port can stream on your Jio account. Keep the port off the open internet: OpenWrt's `wan` zone rejects inbound traffic by default, so don't add a port forward.

To watch from elsewhere, use [Tailscale](https://tailscale.com) on the router with a subnet route:

```sh
tailscale up --advertise-routes=192.168.1.0/24   # add --advertise-exit-node to also use home as your internet exit
```

Approve the route in the Tailscale admin console under **Machines → router → Edit route settings**. Then any device on your tailnet can open `http://<router-ip>:5001` from anywhere.

TVs and set-top boxes need the Tailscale app. It is available on Android TV, Fire TV and Apple TV.
