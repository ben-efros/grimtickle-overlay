# lxc → app-emulation/lxc-pve

## Overview

pxvirt ships a patched version of LXC (`lxc-pve`) with additional features needed by
`pve-container`: cgroup v2 support, custom network hook scripts, AppArmor profile
integration, and pxvirt-specific container lifecycle hooks.

## Upstream

- **pxvirt source:** `packages/lxc/lxc/`
- **Debian package:** `lxc-pve`
- **Build system:** autotools (`./configure` + `make`)

## Portage Atom

```
app-emulation/lxc-pve
```

> **Note:** This conflicts with `app-emulation/lxc` from the Gentoo main tree.
> Use a package mask or `package.provided` to avoid the conflict.

## Key Dependencies

| Debian | Gentoo atom | Notes |
|--------|-------------|-------|
| `libseccomp-dev` | `sys-libs/libseccomp` | Syscall filtering |
| `libapparmor-dev` | `sys-apps/apparmor` | USE=apparmor |
| `libcap-dev` | `sys-libs/libcap` | Capability management |
| `libglib2.0-dev` | `dev-libs/glib` | |
| `bash-completion` | `app-shells/bash-completion` | Optional |

## USE Flags

| Flag | Effect |
|------|--------|
| `apparmor` | Enable AppArmor MAC profiles for containers |
| `seccomp` | Enable seccomp syscall filtering (recommended) |
| `cgroupv2` | Force cgroup v2 (requires kernel ≥ 5.14 with cgroup v2) |

## Ebuild Notes

- Use `inherit autotools`
- Pass `--enable-apparmor`, `--enable-seccomp`, `--disable-tests` to configure
- Conflicting files with `app-emulation/lxc`: add `!app-emulation/lxc` to `CONFLICTS`
- AppArmor profiles installed to `/etc/apparmor.d/lxc/`

## Kernel Requirements

```
CONFIG_NAMESPACES=y
CONFIG_UTS_NS=y
CONFIG_IPC_NS=y
CONFIG_USER_NS=y
CONFIG_PID_NS=y
CONFIG_NET_NS=y
CONFIG_CGROUPS=y
CONFIG_CGROUP_DEVICE=y
CONFIG_CGROUP_FREEZER=y
CONFIG_CGROUP_NET_CLASSID=y
CONFIG_CGROUP_PERF=y
CONFIG_CGROUP_HUGETLB=y
CONFIG_CPUSETS=y
CONFIG_MEMCG=y
CONFIG_KEYS=y
CONFIG_SECCOMP=y
CONFIG_SECCOMP_FILTER=y
```

## Architecture Notes

C source; compiles on ARM64 and LoongArch. Check patch series for arch-specific patches
(`series.arm64`). `KEYWORDS="~arm64 ~loong"`.
