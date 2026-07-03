# lxc → app-emulation/lxc-pve

## Overview

pxvirt ships a patched version of LXC 6.0.5 (`lxc-pve`) with security hardening and
pxvirt-specific configuration. It is the container runtime used by `pve-container` (the
`pct` command) for LXC container management.

**Ebuild status:** ✅ Written — `app-emulation/lxc-pve/lxc-pve-6.0.5.ebuild`

## Upstream

- **LXC upstream version:** 6.0.5
- **pxvirt source:** `packages/lxc/lxc/` (submodule of lxc 6.0.5)
- **Debian package:** `lxc-pve`
- **Build system:** **Meson** (≥ 0.61) — *not autotools*
- **Source tarball:** `https://linuxcontainers.org/downloads/lxc/lxc-6.0.5.tar.gz`

## Portage Atom

```
app-emulation/lxc-pve
```

> **No conflict with Gentoo tree.** `app-emulation/lxc` does **not** exist in the
> Gentoo main tree (only `acct-group/lxc` and `acct-user/lxc`). No BLOCK needed.

## pxvirt Patches Applied

4 patches from `packages/lxc/lxc/debian/patches/`, now in `files/`:

| Patch | Effect |
|-------|--------|
| `0001-PVE-Config-deny-rw-mounting-of-sys-and-proc.patch` | AppArmor: deny rw remounting of `/sys`/`/proc` from containers (security hardening) |
| `0002-PVE-Config-attach-always-use-getent.patch` | Force `lxc-attach` to use `getent` for user lookup (avoids NSS segfault in some distros) |
| `0001-apparmor-allow-lxc-start-to-create-user-namespaces.patch` | Add `userns` permission to AppArmor `start-container` profile |
| `0002-apparmor-use-abi-directive-in-apparmor-profiles.patch` | Add `abi <abi/lxc>` directive to profiles (avoids needing global AppArmor feature pinning) |

## Meson Configure Flags (matching pxvirt Debian build)

```
-Dcgroup-pattern=lxc/%n
-Dexamples=false
-Dinit-script=systemd
-Dspecfile=false
-Dtests=false
-Dapparmor=true      # USE=apparmor
-Dcapabilities=true  # USE=capabilities
-Dseccomp=true       # USE=seccomp
-Dselinux=false      # USE=selinux (off by default)
```

## Dependencies

### Build deps
| Dep | Gentoo atom |
|-----|-------------|
| meson ≥ 0.61 | `dev-build/meson` |
| pkg-config | `virtual/pkgconfig` |
| python3 + jinja2 | `dev-lang/python`, `dev-python/jinja2` (for meson template processing) |
| libapparmor headers | `sys-apps/apparmor` (USE=apparmor) |
| libcap headers | `sys-libs/libcap` (USE=capabilities) |
| libseccomp headers | `sys-libs/libseccomp` (USE=seccomp) |
| gnutls headers | `net-libs/gnutls` |
| dbus headers | `sys-apps/dbus` |
| systemd headers | `sys-apps/systemd` |
| doxygen + docbook2X | doc? only |

### Runtime deps
| Debian dep | Gentoo atom | Notes |
|-----------|-------------|-------|
| `apparmor` | `sys-apps/apparmor` | USE=apparmor |
| `bridge-utils` | `net-misc/bridge-utils` | For container networking |
| `criu` | `sys-process/criu` | USE=criu; checkpoint/restore |
| `libcap2` | `sys-libs/libcap` | |
| `lxcfs` | `sys-fs/lxcfs` | ✅ Already in Gentoo tree as `sys-fs/lxcfs` |
| `python3` | `dev-lang/python` | For LXC template hooks |
| `uidmap` (newuidmap/newgidmap) | `sys-apps/shadow` | For unprivileged containers |

## USE Flags

| Flag | Default | Effect |
|------|---------|--------|
| `apparmor` | ON | AppArmor MAC profiles for containers |
| `capabilities` | ON | POSIX capabilities via libcap |
| `criu` | off | Checkpoint/restore support |
| `doc` | off | Build Doxygen API docs and man pages |
| `seccomp` | ON | Seccomp syscall filtering |
| `selinux` | off | SELinux support |

## Special Install Notes

- **`lxc-user-nic`** is setuid root (needed for unprivileged container networking).
  The ebuild explicitly sets `4755` on this binary in `src_install()`.
- **subuid/subgid:** `pkg_postinst()` runs `usermod -v 100000-165535 -w 100000-165535 root`
  to configure the UID/GID mapping range for root's unprivileged containers.
- **AppArmor profiles** are installed to `/etc/apparmor.d/` and must be loaded manually
  after install (see `pkg_postinst` elog messages).
- **Runtime directories** `/var/cache/lxc`, `/var/lib/lxc`, `/var/log/lxc` are created
  via `keepdir`.

## Ebuild File Layout

```
app-emulation/lxc-pve/
├── lxc-pve-6.0.5.ebuild
├── metadata.xml
├── Manifest
└── files/
    ├── 0001-PVE-Config-deny-rw-mounting-of-sys-and-proc.patch
    ├── 0001-apparmor-allow-lxc-start-to-create-user-namespaces.patch
    ├── 0002-PVE-Config-attach-always-use-getent.patch
    └── 0002-apparmor-use-abi-directive-in-apparmor-profiles.patch
```

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

For cgroup v2 (default on modern systems):
```
CONFIG_CGROUP_BPF=y
```

## Architecture Notes

C source (meson build). No arch-specific patches in the pxvirt series — the 4 patches
apply cleanly to ARM64 and LoongArch. `KEYWORDS="~arm64 ~loong"`.

## Quick Install

```bash
emerge --ask app-emulation/lxc-pve
# With all recommended flags:
echo 'app-emulation/lxc-pve apparmor capabilities seccomp' >> /etc/portage/package.use/pxvirt
emerge app-emulation/lxc-pve
```

