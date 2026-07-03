# Overview: pxvirt on Gentoo

## What is pxvirt?

**pxvirt** (formerly Proxmox-Port) is an open-source virtualization platform derived from
[Proxmox VE](https://www.proxmox.com/), specifically adapted to support **ARM64** and
**LoongArch** architectures. It provides:

- KVM/QEMU-based virtual machine management
- LXC container management
- Web-based management interface (pvemanager)
- Storage management (ZFS, Ceph, LVM, NFS, iSCSI, and more)
- SDN networking configuration
- Cluster and High Availability management

pxvirt is AGPL-3.0 licensed and is not affiliated with Proxmox Server Solutions GmbH.
Its source lives at the companion `pxvirt` repository and is organized as a collection of
Debian source packages, each a git submodule.

---

## Why Port to Gentoo?

Proxmox VE and pxvirt are distributed exclusively as Debian-based systems. The Gentoo port
addresses several limitations of this approach:

| Concern | Debian/pxvirt | Gentoo/grimtickle-overlay |
|---------|--------------|--------------------------|
| Architecture | amd64, arm64, loong (via patches) | Any arch Gentoo supports |
| Package granularity | Monolithic `.deb` sets | Fine-grained USE flags per package |
| Kernel | Proxmox-patched Debian kernel | Any kernel (e.g., cix-sources in this overlay) |
| Networking | `ifupdown2` / `/etc/network/interfaces` | systemd-networkd or NetworkManager |
| Init system | systemd (Debian-configured) | systemd or OpenRC via Gentoo profile |
| Build reproducibility | Docker + deb builder | Portage + ebuild |

Gentoo's source-based model allows fine-grained control over which features are compiled in,
making it practical to build a minimal hypervisor node without desktop or server bloat.

---

## Project Architecture

```
grimtickle-overlay/         ← this overlay (Gentoo package tree)
├── metadata/               ← overlay metadata (masters = gentoo)
├── profiles/               ← overlay profiles
├── dev-vcs/                ← e.g., xet-core
├── sys-cluster/            ← ceph, corosync-pve, pve-cluster (planned)
├── sys-kernel/             ← cix-sources (custom kernel for ARM SoCs)
├── app-emulation/          ← QEMU pve, LXC pve, containers (planned)
├── dev-perl/               ← all PVE Perl library packages (planned)
├── www-apps/               ← web UI assets: extjs, novnc, etc. (planned)
├── sys-apps/               ← pve-manager daemon (planned)
├── net-misc/               ← pve-network (planned)
└── docs/                   ← this documentation

pxvirt/                     ← upstream package sources (separate repo)
└── packages/
    ├── pve-common/         ← Perl utility libraries
    ├── pve-qemu/           ← QEMU patched for PVE
    ├── pve-manager/        ← main web UI and API daemon
    └── ...                 ← ~80 packages total
```

### Relationship to Upstream

```
Proxmox VE (upstream)
    │
    ▼ fork
pxvirt (ARM64 / LoongArch patches + rebrand)
    │
    ▼ Gentoo port
grimtickle-overlay (this overlay)
```

Changes flow: Proxmox VE → pxvirt submodule updates → ebuild version bumps in this overlay.

---

## Overlay Configuration

The overlay uses the Gentoo tree as its master (inherits all standard eclasses and packages):

```ini
# metadata/layout.conf
masters = gentoo
thin-manifests = true
```

Repository name: `grimtickle-overlay`

---

## Existing Packages

| Atom | Description | Phase |
|------|-------------|-------|
| `dev-vcs/xet-core` | Hugging Face Xet git storage backend (Rust) | — |
| `sys-cluster/ceph` | Ceph storage (v20.2.2) | Phase 4 |
| `sys-kernel/cix-sources` | Linux kernel sources for CIX ARM SoCs | — |

---

## Architecture Support

All ebuilds in this overlay should be tested or keyword-masked for:

- `~arm64` — 64-bit ARM (AArch64), the primary pxvirt target
- `~loong` — LoongArch 64-bit (LoongArch64), secondary pxvirt target

The standard Gentoo `x86`/`amd64` targets are not a primary concern of this overlay but
ebuilds should avoid unnecessarily excluding them.

---

## Further Reading

- [Porting Plan](porting-plan.md) — phased roadmap
- [Build Guide](build-guide.md) — how to install and use this overlay
- [Networking Guide](networking.md) — VM bridge setup without ifupdown2
- [Package Index](packages/README.md) — all packages, deps, and portage atoms
