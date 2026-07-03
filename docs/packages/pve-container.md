# pve-container → app-emulation/pve-container

## Overview

`pve-container` is the Perl management layer for Linux Containers in pxvirt. It provides
the `pct` CLI tool and the REST API endpoints for creating, starting, stopping, migrating,
and backing up LXC containers.

## Upstream

- **pxvirt source:** `packages/pve-container/pve-container/`
- **Debian package:** `pve-container`
- **Build system:** Makefile + Perl

## Portage Atom

```
app-emulation/pve-container
```

## Key Dependencies

| Debian | Gentoo atom |
|--------|-------------|
| `lxc-pve` | `app-emulation/lxc-pve` |
| `lxcfs` | `app-emulation/lxcfs` |
| `libpve-common-perl` | `dev-perl/libpve-common-perl` |
| `libpve-guest-common-perl` | `dev-perl/libpve-guest-common-perl` |
| `libpve-storage-perl` | `dev-perl/libpve-storage-perl` |
| `libpve-access-control` | `dev-perl/libpve-access-control` |
| `binutils` | `sys-devel/binutils` | For CT rootfs manipulation |
| `rsync` | `net-misc/rsync` | CT migration |
| `tar` | `app-arch/tar` | CT backup/restore |

## Ebuild Notes

- Use `inherit perl-module`
- Installs `pct` to `/usr/bin/`
- Also installs LXC hook scripts to `/usr/share/lxc/hooks/`
- CT templates are downloaded separately (not part of this ebuild)

## Architecture Notes

Pure Perl; arch-independent (`KEYWORDS="~arm64 ~loong ~amd64"`).
