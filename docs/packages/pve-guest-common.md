# pve-guest-common → dev-perl/libpve-guest-common-perl

## Overview

`pve-guest-common` provides shared abstractions used by both `qemu-server` (VMs) and
`pve-container` (CTs). It includes guest firewall rules, replication framework hooks,
snapshot/backup logic, and the guest config parser base class.

## Upstream

- **pxvirt source:** `packages/pve-guest-common/pve-guest-common/`
- **Debian package:** `libpve-guest-common-perl`
- **Build system:** Makefile + Perl

## Portage Atom

```
dev-perl/libpve-guest-common-perl
```

## Key Dependencies

| Debian | Gentoo atom |
|--------|-------------|
| `libpve-access-control` | `dev-perl/libpve-access-control` |
| `libpve-common-perl` | `dev-perl/libpve-common-perl` |
| `libpve-storage-perl` | `dev-perl/libpve-storage-perl` |

## Ebuild Notes

- Use `inherit perl-module`
- Pure Perl, no XS
- Depends on pve-storage; install after storage layer is available

## Architecture Notes

Pure Perl; arch-independent (`KEYWORDS="~arm64 ~loong ~amd64"`).
