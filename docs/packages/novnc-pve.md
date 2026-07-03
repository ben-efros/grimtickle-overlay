# novnc-pve → www-apps/novnc-pve

## Overview

`novnc-pve` ships the pxvirt-patched noVNC JavaScript client used to provide in-browser
VNC console access to VMs. It is embedded in the web UI and communicates with `vncterm`
or QEMU's built-in VNC server via a WebSocket proxy.

## Upstream

- **pxvirt source:** `packages/novnc-pve/novnc-pve/`
- **Debian package:** `novnc-pve`
- **Build system:** Static files

## Portage Atom

```
www-apps/novnc-pve
```

## Key Dependencies

None — arch-independent static assets.

## Ebuild Notes

- Install to `/usr/share/novnc-pve/`
- `KEYWORDS="~arm64 ~loong ~amd64"` (arch-independent)
- No compilation step

## Notes

pxvirt ships a patched version of noVNC (not the upstream `app-misc/novnc`). Do not
substitute with the upstream Gentoo noVNC package — the pxvirt patches add clipboard
support and WebSocket auth that the web UI depends on.
