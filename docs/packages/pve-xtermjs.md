# pve-xtermjs → www-apps/pve-xtermjs

## Overview

`pve-xtermjs` provides the xterm.js-based terminal emulator for the pxvirt web UI.
It is used for the QEMU/LXC console (shell) tab and communicates with `vncterm` or
a WebSocket tunnel to the host's PTY.

## Upstream

- **pxvirt source:** `packages/pve-xtermjs/pve-xtermjs/`
- **Debian package:** (check pxvirt source; may be `pve-xtermjs`)
- **Build system:** Node.js / npm or pre-bundled static assets

## Portage Atom

```
www-apps/pve-xtermjs
```

## Key Dependencies

| Build dep | Gentoo atom | Notes |
|-----------|-------------|-------|
| `nodejs` | `net-libs/nodejs` | Build-time only (for npm/webpack bundle) |

No runtime deps beyond the web browser.

## Ebuild Notes

- Install to `/usr/share/pve-xtermjs/`
- `KEYWORDS="~arm64 ~loong ~amd64"` (arch-independent)
- If the pxvirt release ships a pre-built bundle, use that instead of running webpack
  at install time (avoids Node.js build dependency)
- Check `packages/pve-xtermjs/` for a pre-built `dist/` directory

## Notes

xterm.js is MIT-licensed. The pxvirt-specific wrapper code is AGPL-3.0.
