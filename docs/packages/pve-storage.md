# pve-storage → dev-perl/libpve-storage-perl

## Overview

`pve-storage` is the storage plugin layer for pxvirt. It abstracts over ZFS, LVM, Ceph
RBD, NFS, CIFS, iSCSI, GlusterFS, directory storage, and more. The `pvesm` CLI tool is
installed by this package.

## Upstream

- **pxvirt source:** `packages/pve-storage/pve-storage/`
- **Debian package:** `libpve-storage-perl`
- **Build system:** Makefile + Perl

## Portage Atom

```
dev-perl/libpve-storage-perl
```

## Key Dependencies

| Debian | Gentoo atom | Notes |
|--------|-------------|-------|
| `libpve-common-perl` | `dev-perl/libpve-common-perl` | |
| `bcache-tools` | `sys-block/bcache-tools` | Optional |
| `ceph-common` | `sys-cluster/ceph` | USE=ceph |
| `lvm2` | `sys-fs/lvm2` | USE=lvm |
| `nfs-common` | `net-fs/nfs-utils` | USE=nfs |
| `open-iscsi` | `sys-block/open-iscsi` | USE=iscsi |
| `zfsutils-linux` | `sys-fs/zfs` | USE=zfs |
| `multipath-tools` | `sys-fs/multipath-tools` | Optional |
| `librados2-perl` | `dev-perl/librados2-perl` | USE=ceph |

## USE Flags

| Flag | Effect |
|------|--------|
| `zfs` | Enables ZFS storage plugin; pulls in `sys-fs/zfs` |
| `ceph` | Enables Ceph RBD plugin; pulls in `sys-cluster/ceph` and `dev-perl/librados2-perl` |
| `lvm` | Enables LVM/LVM-thin plugin; pulls in `sys-fs/lvm2` |
| `nfs` | Enables NFS storage; pulls in `net-fs/nfs-utils` |
| `iscsi` | Enables iSCSI; pulls in `sys-block/open-iscsi` |

## Ebuild Notes

- Use `inherit perl-module`
- `pvesm` tool installed to `/usr/bin/`
- Storage config lives in `/etc/pve/storage.cfg` (managed at runtime)

## Architecture Notes

Pure Perl; arch-independent (`KEYWORDS="~arm64 ~loong ~amd64"`).
