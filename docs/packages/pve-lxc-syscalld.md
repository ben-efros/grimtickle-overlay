# pve-lxc-syscalld → app-emulation/pve-lxc-syscalld

## Overview

`pve-lxc-syscalld` is a small Rust daemon that intercepts certain privileged syscalls
from unprivileged LXC containers and executes them on the container's behalf. This allows
operations like `mknod` in unprivileged containers safely.

## Upstream

- **pxvirt source:** `packages/pve-lxc-syscalld/pve-lxc-syscalld/`
- **Debian package:** `pve-lxc-syscalld`
- **Build system:** Cargo (Rust)

## Portage Atom

```
app-emulation/pve-lxc-syscalld
```

## Key Dependencies

| Debian | Gentoo atom |
|--------|-------------|
| `libseccomp-dev` | `sys-libs/libseccomp` |
| Rust toolchain | `dev-lang/rust` |

## Ebuild Notes

- Use `inherit cargo`
- Vendor crate dependencies with `cargo vendor` and include in SRC_URI
- Install to `/usr/lib/pve-lxc-syscalld/`
- systemd socket unit: `pve-lxc-syscalld.socket` + `pve-lxc-syscalld.service`

## Architecture Notes

Rust; `KEYWORDS="~arm64 ~loong"`. Ensure `dev-lang/rust` supports the target triple:
- ARM64: `aarch64-unknown-linux-gnu`
- LoongArch: `loongarch64-unknown-linux-gnu` (requires Rust ≥ 1.71 for loong support)
