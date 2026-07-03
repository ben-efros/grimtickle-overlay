# pve-cluster → sys-cluster/pve-cluster

## Overview

`pve-cluster` provides `pmxcfs` — the Proxmox Cluster File System, a FUSE-based
distributed filesystem backed by SQLite and synchronized via Corosync. All cluster
configuration (VM configs, network configs, auth data) is stored in `/etc/pve/` which
is the pmxcfs mount point.

`pve-cluster` also provides the Perl API library `libpve-cluster-perl` used by
`pve-manager` and other components.

## Upstream

- **pxvirt source:** `packages/pve-cluster/pve-cluster/`
- **Debian packages:** `pve-cluster`, `libpve-cluster-perl`, `libpve-cluster-api-perl`, `libpve-notify-perl`
- **Build system:** Makefile (C + Perl)

## Portage Atom

```
sys-cluster/pve-cluster
```

## Key Dependencies

| Debian | Gentoo atom |
|--------|-------------|
| `corosync` | `sys-cluster/corosync-pve` |
| `libfuse3-dev` | `sys-fs/fuse:3` |
| `libsqlite3-dev` | `dev-db/sqlite` |
| `libgcrypt-dev` | `dev-libs/libgcrypt` |
| `libqb-dev` | `sys-libs/libqb` |
| `libpve-common-perl` | `dev-perl/libpve-common-perl` |
| `libpve-access-control` | `dev-perl/libpve-access-control` |
| `libcrypt-ssleay-perl` | `dev-perl/Crypt-SSLeay` |
| `check` | `dev-libs/check` (build, unit tests) |
| `faketime` | `sys-libs/faketime` (build, tests) |

## Ebuild Notes

- Use `inherit perl-module` (or split into C + Perl packages)
- `pmxcfs` binary: `/usr/bin/pmxcfs`
- systemd unit: `pve-cluster.service` — must start before `pvedaemon`
- FUSE mount: mounts `/etc/pve/` at startup — kernel must have `CONFIG_FUSE_FS=y`
- Perl libs: `libpve-cluster-perl`, `libpve-cluster-api-perl`, `libpve-notify-perl`
  can be installed from the same source

## Single-Node Alternative

On a standalone node without cluster, `/etc/pve/` should be a plain directory.
Do not run `pve-cluster.service` in this case. See `pve-manager.md` for details.

## Architecture Notes

Mixed C + Perl. C components need arch-specific compile. `KEYWORDS="~arm64 ~loong"`.
