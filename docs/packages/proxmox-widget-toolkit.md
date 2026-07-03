# proxmox-widget-toolkit → www-apps/proxmox-widget-toolkit

## Overview

`proxmox-widget-toolkit` is the pxvirt-specific ExtJS widget library. It extends ExtJS
with PVE-specific components: VM/CT panels, storage browsers, network editors, task logs,
and the main navigation tree.

## Upstream

- **pxvirt source:** `packages/proxmox-widget-toolkit/proxmox-widget-toolkit/`
- **Debian package:** `proxmox-widget-toolkit`
- **Build system:** Makefile (JS concatenation + minification)

## Portage Atom

```
www-apps/proxmox-widget-toolkit
```

## Key Dependencies

| Debian | Gentoo atom |
|--------|-------------|
| `libjs-extjs` | `www-apps/libjs-extjs` |

## Ebuild Notes

- Install to `/usr/share/javascript/proxmox-widget-toolkit/`
- The Makefile runs `uglify-js` or similar to minify; this may require
  `net-libs/nodejs` at build time. Alternatively, use the pre-built artifacts
  from the pxvirt release.
- `KEYWORDS="~arm64 ~loong ~amd64"` (arch-independent)

## Notes

A `-dev` variant (`proxmox-widget-toolkit-dev`) ships the unminified source for
development. This can be installed alongside for debugging the web UI.
