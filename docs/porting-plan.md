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

## Critical Path

> ⚠️ These packages block everything. Build them first.

```
dev-lang/rust (≥ 1.75)
    └── dev-perl/libproxmox-rs-perl   ← BLOCKS ALL PVE PERL PACKAGES
            └── dev-perl/libpve-common-perl   ← BLOCKS ENTIRE MANAGEMENT STACK
```

See [dependency-implications.md](dependency-implications.md) for the full breakdown of
what breaks when each package is absent.

---

## Gentoo Tree Audit Results

Before writing overlay ebuilds, these packages were confirmed **already in the Gentoo
main tree** and do NOT need overlay ebuilds (unless pxvirt patches are required):

| Package | Gentoo atom | Notes |
|---------|-------------|-------|
| libqb | `sys-cluster/libqb` ✅ | v2.0.8+ |
| kronosnet | `sys-cluster/kronosnet` ✅ | v1.19+ |
| corosync | `sys-cluster/corosync` ✅ | v3.1.0 — **must verify ABI with pve-cluster patches** |
| frr | `net-misc/frr` ✅ | v10.x — for BGP/EVPN SDN |
| swtpm | `app-crypt/swtpm` ✅ | v0.10.0 — vTPM support |
| libtpms | `dev-libs/libtpms` ✅ | v0.10.x |
| lxcfs | `sys-fs/lxcfs` ✅ | v6.x — **note: sys-fs/ not app-emulation/** |
| pixman | `x11-libs/pixman` ✅ | |
| libgit2 | `dev-libs/libgit2` ✅ | |
| libseccomp | `sys-libs/libseccomp` ✅ | |
| postfix | `mail-mta/postfix` ✅ | satisfies mail-transport-agent dep |
| edk2-bin | `sys-firmware/edk2-bin` ✅ | x86 **only** — need pve-edk2-firmware for ARM64/loong |

**Not in Gentoo tree — overlay ebuilds required:**

| Package | Notes |
|---------|-------|
| `app-emulation/lxc-pve` | No conflict — `app-emulation/lxc` does not exist in tree |
| `app-emulation/spiceterm` | Not in tree |
| `sys-apps/proxmox-mini-journalreader` | Not in tree; hard dep of pve-manager |
| `sys-apps/proxmox-mail-forward` | Not in tree; hard dep of pve-manager |
| `sys-apps/proxmox-rrd-migration-tool` | Not in tree; hard dep of pve-manager |
| `www-apps/libjs-qrcodejs` | Not in tree; hard dep of pve-manager |
| `sys-firmware/pve-edk2-firmware` | ARM64/LoongArch UEFI blobs; edk2-bin is x86-only |

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
| `libjs-qrcodejs` | `www-apps/libjs-qrcodejs` | Static assets | QR codes for TOTP; **hard dep of pve-manager** |
| `proxmox-mini-journalreader` | `sys-apps/proxmox-mini-journalreader` | C/Rust | Task log viewer; **hard dep of pve-manager** |
| `proxmox-mail-forward` | `sys-apps/proxmox-mail-forward` | Shell/Perl | Mail relay; **hard dep of pve-manager** |
| `proxmox-rrd-migration-tool` | `sys-apps/proxmox-rrd-migration-tool` | Rust | RRD stats tool; **hard dep of pve-manager** |
| `pve-edk2-firmware` | `sys-firmware/pve-edk2-firmware` | EDK2 cross-build | ARM64+LoongArch UEFI; **ARM64 VMs unusable without this** |
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
| `lxc` | `app-emulation/lxc-pve` | pxvirt-patched LXC; **no conflict** — `app-emulation/lxc` does not exist in Gentoo tree |
| `lxcfs` | `sys-fs/lxcfs` ✅ | **Already in Gentoo tree** as `sys-fs/lxcfs` (not app-emulation/) |
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
| `kronosnet` | `sys-cluster/kronosnet` ✅ | **Already in Gentoo tree** (v1.19+) |
| `libqb` | `sys-cluster/libqb` ✅ | **Already in Gentoo tree** (v2.0.8+) |
| `corosync-pve` | `sys-cluster/corosync-pve` | Gentoo tree has upstream corosync-3.1.0; **must verify ABI compatibility with pve-cluster before deciding if overlay ebuild is needed** |
| `pve-cluster` | `sys-cluster/pve-cluster` | pmxcfs cluster filesystem + Perl libs |
| `pve-ha-manager` | `sys-cluster/pve-ha-manager` | HA resource management |

### Notes
- `kronosnet` and `libqb` are confirmed in the Gentoo tree — no overlay ebuilds needed.
- `corosync`: upstream `sys-cluster/corosync-3.1.0` is in tree. **Before writing a corosync-pve overlay ebuild, attempt to link pve-cluster against it.** If it succeeds, skip the overlay ebuild and use the tree package.
- `pve-cluster` installs `pmxcfs` (a FUSE-based cluster filesystem using Corosync).
- Cluster requires an odd number of nodes (or a QDevice) for quorum.
- On a standalone node, see [single-node-bootstrap.md](single-node-bootstrap.md) to run pve-manager without pve-cluster.

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
| pve-edk2-firmware ⚠️ | `sys-firmware/pve-edk2-firmware` | 1 | 🔲 | 🔲 | 🔲 | 🔲 |
| extjs | `www-apps/libjs-extjs` | 1 | 🔲 | 🔲 | ✅ | ✅ |
| proxmox-widget-toolkit | `www-apps/proxmox-widget-toolkit` | 1 | 🔲 | 🔲 | ✅ | ✅ |
| novnc-pve | `www-apps/novnc-pve` | 1 | 🔲 | 🔲 | ✅ | ✅ |
| pve-xtermjs | `www-apps/pve-xtermjs` | 1 | 🔲 | 🔲 | ✅ | ✅ |
| vncterm | `app-emulation/vncterm` | 1 | 🔲 | 🔲 | 🔲 | 🔲 |
| libjs-qrcodejs ⚠️ | `www-apps/libjs-qrcodejs` | 1 | 🔲 | 🔲 | ✅ | ✅ |
| proxmox-mini-journalreader ⚠️ | `sys-apps/proxmox-mini-journalreader` | 1 | 🔲 | 🔲 | 🔲 | 🔲 |
| proxmox-mail-forward ⚠️ | `sys-apps/proxmox-mail-forward` | 1 | 🔲 | 🔲 | 🔲 | 🔲 |
| proxmox-rrd-migration-tool ⚠️ | `sys-apps/proxmox-rrd-migration-tool` | 1 | 🔲 | 🔲 | 🔲 | 🔲 |
| proxmox-acme ⚠️ | `dev-perl/libproxmox-acme-perl` | 1 | 🔲 | 🔲 | 🔲 | 🔲 |
| libpve-notify-perl ⚠️ | `dev-perl/libpve-notify-perl` | 1 | 🔲 | 🔲 | 🔲 | 🔲 |
| pve-manager | `sys-apps/pve-manager` | 1 | 🔲 | 🔲 | 🔲 | 🔲 |
| lxc-pve | `app-emulation/lxc-pve` | 2 | 🔲 | 🔲 | 🔲 | 🔲 |
| lxcfs | `sys-fs/lxcfs` ✅ | 2 | — | ✅ | 🔲 | 🔲 |
| pve-lxc-syscalld | `app-emulation/pve-lxc-syscalld` | 2 | 🔲 | 🔲 | 🔲 | 🔲 |
| pve-container | `app-emulation/pve-container` | 2 | 🔲 | 🔲 | 🔲 | 🔲 |
| kronosnet | `sys-cluster/kronosnet` ✅ | 3 | — | ✅ | 🔲 | 🔲 |
| libqb | `sys-cluster/libqb` ✅ | 3 | — | ✅ | 🔲 | 🔲 |
| corosync-pve | `sys-cluster/corosync-pve` (or tree) | 3 | ❓ | ❓ | 🔲 | 🔲 |
| pve-cluster | `sys-cluster/pve-cluster` | 3 | 🔲 | 🔲 | 🔲 | 🔲 |
| pve-ha-manager | `sys-cluster/pve-ha-manager` | 3 | 🔲 | 🔲 | 🔲 | 🔲 |
| pve-firewall | `net-firewall/pve-firewall` | 4 | 🔲 | 🔲 | 🔲 | 🔲 |
| proxmox-backup | `app-backup/proxmox-backup` | 4 | 🔲 | 🔲 | 🔲 | 🔲 |
| ceph | `sys-cluster/ceph` ✅ | 4 | ✅ | 🔧 | 🔲 | 🔲 |

Legend: ✅ done · 🔧 in progress · 🔲 not started · — not applicable (from Gentoo tree) · ❓ TBD (ABI check needed)

⚠️ = **Hard dependency of pve-manager** — must be built before `emerge sys-apps/pve-manager` will succeed.
