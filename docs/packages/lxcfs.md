# lxcfs → app-emulation/lxcfs

## Overview

`lxcfs` is a FUSE filesystem that provides container-aware `/proc` and `/sys` views.
It makes containers see their own cgroup limits (rather than the host's) for CPU, memory,
and uptime. Used by pxvirt for accurate resource reporting inside containers.

## Upstream

- **pxvirt source:** `packages/lxcfs/lxcfs/`
- **Debian package:** `lxcfs`
- **Build system:** meson

## Portage Atom

```
app-emulation/lxcfs
```

> **Check first:** `lxcfs` may already exist in the Gentoo main tree as
> `app-emulation/lxcfs`. If the version is compatible, no overlay ebuild is needed.

## Key Dependencies

| Debian | Gentoo atom |
|--------|-------------|
| `libfuse3-dev` | `sys-fs/fuse:3` |
| `meson` | `dev-build/meson` (build) |

## Ebuild Notes

- Use `inherit meson`
- Standard meson configure/compile/install
- Binary: `/usr/bin/lxcfs`
- systemd unit: `lxcfs.service` — enable with `systemctl enable --now lxcfs`
- FUSE mount point: `/var/lib/lxcfs/`

## Architecture Notes

C source; arch-independent logic. `KEYWORDS="~arm64 ~loong ~amd64"`.
