# pxvirt Gentoo Porting Plan

This document describes the phased strategy for porting pxvirt into the Gentoo environment
via the `grimtickle-overlay`. The goal is a fully `emerge`-installable pxvirt node with no
Debian, dpkg, or apt involvement.

---

## Design Principles

1. **No Debian runtime** — no `dpkg`, `apt`, `ifupdown2`, or `/etc/network/interfaces`.
2. **Emerge installs everything** — each pxvirt component has an ebuild in this overlay.
3. **Phase-gated** — start with a minimal single-node hypervisor, expand outward.
4. **Upstream tracking** — ebuilds pin to pxvirt versions; bumping the submodule triggers
   a version bump in the ebuild.
5. **Arch-first** — all ebuilds must work on `~arm64` and `~loong` before `~amd64`.

---

## Phases at a Glance

| Phase | Name | Key packages | Outcome |
|-------|------|-------------|---------|
| 1 | Minimal Viable Node | pve-manager, pve-qemu, pve-storage, web UI | Single-node KVM hypervisor |
| 2 | LXC Containers | lxc-pve, pve-container | CT management alongside VMs |
| 3 | Cluster & HA | corosync-pve, pve-cluster, pve-ha-manager | Multi-node cluster |
| 4 | Advanced | pve-firewall, proxmox-acme, proxmox-backup, Ceph | Production hardening |

---

## Phase 1 — Minimal Viable Node

**Goal:** A single Gentoo machine running `pvemanager` that can create and manage KVM VMs
through the web interface, with basic storage and bridged networking.

### Build-order dependency chain

```
proxmox-perl-rs / proxmox-ve-rs   (Rust→Perl FFI glue)
        │
        ▼
   pve-common  (libpve-common-perl)
        │
   ┌────┴────────────────────┐
   ▼                         ▼
pve-http-server          pve-access-control
   │                         │
   └────────┬────────────────┘
            ▼
      pve-guest-common
            │
     ┌──────┴──────┐
     ▼             ▼
 pve-storage   pve-network
     │
     ▼
 qemu-server  ←──── pve-qemu (patched QEMU binary)
     │
     ▼
 pve-manager
     │
     ├── extjs
     ├── proxmox-widget-toolkit
     ├── novnc-pve
     ├── pve-xtermjs
     └── vncterm
```

### Phase 1 package list

| pxvirt package | Portage atom | Build system | Notes |
|----------------|-------------|-------------|-------|
| `proxmox-perl-rs` | `dev-perl/libproxmox-rs-perl` | Rust + Perl FFI | Requires Rust toolchain |
| `proxmox-ve-rs` | `dev-perl/libpve-rs-perl` | Rust + Perl FFI | Requires Rust toolchain |
| `pve-common` | `dev-perl/libpve-common-perl` | Makefile + Perl | Core Perl utilities |
| `pve-http-server` | `dev-perl/libpve-http-server-perl` | Makefile + Perl | AnyEvent HTTP server |
| `pve-access-control` | `dev-perl/libpve-access-control` | Makefile + Perl | Auth/PAM/2FA |
| `pve-guest-common` | `dev-perl/libpve-guest-common-perl` | Makefile + Perl | Shared VM/CT code |
| `pve-storage` | `dev-perl/libpve-storage-perl` | Makefile + Perl | Storage plugin layer |
| `pve-network` | `net-misc/libpve-network-perl` | Makefile + Perl | Network config abstraction |
| `pve-qemu` | `app-emulation/pve-qemu-kvm` | GNU autotools | Patched QEMU binary |
| `qemu-server` | `app-emulation/qemu-server` | Makefile + Perl | VM lifecycle management |
| `extjs` | `www-apps/libjs-extjs` | Static assets | JavaScript UI framework |
| `proxmox-widget-toolkit` | `www-apps/proxmox-widget-toolkit` | Static assets | PVE ExtJS widgets |
| `novnc-pve` | `www-apps/novnc-pve` | Static assets | noVNC web console |
| `pve-xtermjs` | `www-apps/pve-xtermjs` | Node.js build | xterm.js terminal |
| `vncterm` | `app-emulation/vncterm` | CMake | VNC terminal emulator |
| `pve-manager` | `sys-apps/pve-manager` | Makefile + Perl | Top-level daemon + web UI |

### Phase 1 system dependencies (from main Gentoo tree)

| Gentoo atom | Purpose |
|-------------|---------|
| `dev-lang/perl` | Perl runtime |
| `dev-lang/rust` | For proxmox-*-rs packages |
| `dev-libs/openssl` | TLS everywhere |
| `net-misc/curl` | HTTP client |
| `app-arch/zstd`, `app-arch/lz4` | VM disk compression |
| `sys-fs/zfs` (optional) | ZFS storage backend |
| `net-fs/nfs-utils` | NFS storage backend |
| `sys-apps/smartmontools` | Disk health |
| `sys-apps/dmidecode` | Hardware detection |
| `app-misc/jq` | JSON processing |
| `dev-perl/AnyEvent` | Async I/O (Perl) |
| `dev-perl/JSON` | JSON (Perl) |
| `dev-perl/Clone` | Deep-copy (Perl) |
| `dev-perl/Net-IP` | IP address handling |
| `dev-perl/Crypt-OpenSSL-RSA` | RSA crypto (Perl) |
| `virtual/udev` | Device management |

---

## Phase 2 — LXC Containers

**Goal:** Enable Linux Container (CT) management alongside KVM VMs.

**Prerequisite:** Phase 1 complete.

### Phase 2 package list

| pxvirt package | Portage atom | Notes |
|----------------|-------------|-------|
| `lxc` | `app-emulation/lxc-pve` | pxvirt-patched LXC; replaces `app-emulation/lxc` |
| `lxcfs` | `app-emulation/lxcfs` | Likely already in Gentoo tree; check version |
| `pve-lxc-syscalld` | `app-emulation/pve-lxc-syscalld` | Rust daemon for LXC syscall handling |
| `pve-container` | `app-emulation/pve-container` | Perl CT management (pct) |

### Notes
- `lxc-pve` conflicts with upstream `app-emulation/lxc`; use `PROVIDE` or a package mask.
- Kernel must have `CONFIG_CGROUPS`, `CONFIG_NAMESPACES`, `CONFIG_USER_NS` enabled.
- AppArmor profiles ship with `lxc-pve`; on Gentoo, ensure `sys-apps/apparmor` is installed
  or USE=-apparmor to disable.

---

## Phase 3 — Clustering & High Availability

**Goal:** Multi-node pxvirt cluster with quorum, shared config, and HA fencing.

**Prerequisite:** Phase 1 (and optionally Phase 2) complete on each node.

### Phase 3 package list

| pxvirt package | Portage atom | Notes |
|----------------|-------------|-------|
| `kronosnet` | `sys-cluster/kronosnet` | Corosync transport; check Gentoo tree |
| `libqb` | `sys-libs/libqb` | IPC library for corosync; check Gentoo tree |
| `corosync-pve` | `sys-cluster/corosync-pve` | pxvirt-patched corosync |
| `pve-cluster` | `sys-cluster/pve-cluster` | pmxcfs cluster filesystem + Perl libs |
| `pve-ha-manager` | `sys-cluster/pve-ha-manager` | HA resource management |

### Notes
- `kronosnet` and `libqb` may already exist in the Gentoo main tree; check before writing
  overlay ebuilds. Only add overlay versions if patches are required.
- `pve-cluster` installs `pmxcfs` (a FUSE-based cluster filesystem using Corosync).
- Cluster requires an odd number of nodes (or a QDevice) for quorum.

---

## Phase 4 — Advanced / Optional

**Goal:** Production hardening — firewall, TLS cert automation, backup, Ceph.

**Prerequisite:** Phases 1–3 complete.

### Phase 4 package list

| pxvirt package | Portage atom | Notes |
|----------------|-------------|-------|
| `pve-firewall` | `net-firewall/pve-firewall` | Perl + nftables firewall daemon |
| `proxmox-acme` | `dev-perl/libproxmox-acme-perl` | Let's Encrypt ACME client |
| `proxmox-backup` | `app-backup/proxmox-backup` | Rust-based backup server/client |
| Ceph | `sys-cluster/ceph` ✅ | Already in overlay (v20.2.2) |

### Notes
- `pve-firewall` uses `nftables`; ensure `net-firewall/nftables` is installed.
- `proxmox-backup` is a large Rust workspace; use `inherit cargo` with a vendored crate tree.
- Ceph integration in pve-storage requires `sys-cluster/ceph` and `dev-perl/librados2-perl`.

---

## Package Status Table

> Update this table as ebuilds are written.

| Package | Portage atom | Phase | Ebuild | Deps OK | Tested arm64 | Tested loong |
|---------|-------------|-------|--------|---------|-------------|-------------|
| proxmox-perl-rs | `dev-perl/libproxmox-rs-perl` | 1 | 🔲 | 🔲 | 🔲 | 🔲 |
| proxmox-ve-rs | `dev-perl/libpve-rs-perl` | 1 | 🔲 | 🔲 | 🔲 | 🔲 |
| pve-common | `dev-perl/libpve-common-perl` | 1 | 🔲 | 🔲 | 🔲 | 🔲 |
| pve-http-server | `dev-perl/libpve-http-server-perl` | 1 | 🔲 | 🔲 | 🔲 | 🔲 |
| pve-access-control | `dev-perl/libpve-access-control` | 1 | 🔲 | 🔲 | 🔲 | 🔲 |
| pve-guest-common | `dev-perl/libpve-guest-common-perl` | 1 | 🔲 | 🔲 | 🔲 | 🔲 |
| pve-storage | `dev-perl/libpve-storage-perl` | 1 | 🔲 | 🔲 | 🔲 | 🔲 |
| pve-network | `net-misc/libpve-network-perl` | 1 | 🔲 | 🔲 | 🔲 | 🔲 |
| pve-qemu | `app-emulation/pve-qemu-kvm` | 1 | 🔲 | 🔲 | 🔲 | 🔲 |
| qemu-server | `app-emulation/qemu-server` | 1 | 🔲 | 🔲 | 🔲 | 🔲 |
| extjs | `www-apps/libjs-extjs` | 1 | 🔲 | 🔲 | ✅ | ✅ |
| proxmox-widget-toolkit | `www-apps/proxmox-widget-toolkit` | 1 | 🔲 | 🔲 | ✅ | ✅ |
| novnc-pve | `www-apps/novnc-pve` | 1 | 🔲 | 🔲 | ✅ | ✅ |
| pve-xtermjs | `www-apps/pve-xtermjs` | 1 | 🔲 | 🔲 | ✅ | ✅ |
| vncterm | `app-emulation/vncterm` | 1 | 🔲 | 🔲 | 🔲 | 🔲 |
| pve-manager | `sys-apps/pve-manager` | 1 | 🔲 | 🔲 | 🔲 | 🔲 |
| lxc-pve | `app-emulation/lxc-pve` | 2 | 🔲 | 🔲 | 🔲 | 🔲 |
| lxcfs | `app-emulation/lxcfs` | 2 | 🔲 | 🔲 | 🔲 | 🔲 |
| pve-lxc-syscalld | `app-emulation/pve-lxc-syscalld` | 2 | 🔲 | 🔲 | 🔲 | 🔲 |
| pve-container | `app-emulation/pve-container` | 2 | 🔲 | 🔲 | 🔲 | 🔲 |
| corosync-pve | `sys-cluster/corosync-pve` | 3 | 🔲 | 🔲 | 🔲 | 🔲 |
| pve-cluster | `sys-cluster/pve-cluster` | 3 | 🔲 | 🔲 | 🔲 | 🔲 |
| pve-ha-manager | `sys-cluster/pve-ha-manager` | 3 | 🔲 | 🔲 | 🔲 | 🔲 |
| pve-firewall | `net-firewall/pve-firewall` | 4 | 🔲 | 🔲 | 🔲 | 🔲 |
| proxmox-acme | `dev-perl/libproxmox-acme-perl` | 4 | 🔲 | 🔲 | 🔲 | 🔲 |
| proxmox-backup | `app-backup/proxmox-backup` | 4 | 🔲 | 🔲 | 🔲 | 🔲 |
| ceph | `sys-cluster/ceph` ✅ | 4 | ✅ | 🔧 | 🔲 | 🔲 |

Legend: ✅ done · 🔧 in progress · 🔲 not started
