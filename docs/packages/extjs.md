# extjs → www-apps/libjs-extjs

## Overview

`extjs` ships the Sencha ExtJS 7.x JavaScript framework used by the pxvirt web UI.
It is purely static content (minified JS + CSS) with no server-side components.

## Upstream

- **pxvirt source:** `packages/extjs/extjs/`
- **Debian package:** `libjs-extjs`
- **Build system:** Static file install (debhelper)

## Portage Atom

```
www-apps/libjs-extjs
```

## Key Dependencies

None — arch-independent static assets.

## Ebuild Notes

- Use `inherit` (no special eclass needed) or `webapp`
- Install to `/usr/share/javascript/extjs/`
- `KEYWORDS="~arm64 ~loong ~amd64"` (arch-independent)
- No compilation step; `src_install` copies files only

## Notes

ExtJS is proprietary (GPL for open-source use). Sencha ExtJS 7.x is bundled by Proxmox
under the GPL open-source license. Ensure the version shipped in pxvirt matches the
license terms.
