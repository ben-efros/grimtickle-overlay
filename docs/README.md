# grimtickle-overlay Documentation

Gentoo overlay for porting **pxvirt** (a Proxmox VE fork for ARM64 and LoongArch) into the
Gentoo/Portage build environment.

---

## Quick Start

1. Add the overlay → [Build Guide](build-guide.md)
2. Understand the project → [Overview](overview.md)
3. See what gets installed and when → [Porting Plan](porting-plan.md)
4. Configure VM networking on Gentoo → [Networking](networking.md)
5. Find a specific package → [Package Index](packages/README.md)

---

## Documentation Index

| File | Description |
|------|-------------|
| [overview.md](overview.md) | What pxvirt is, why Gentoo, overlay architecture |
| [porting-plan.md](porting-plan.md) | Phased porting roadmap and package status table |
| [networking.md](networking.md) | VM bridge setup for systemd-networkd and NetworkManager |
| [build-guide.md](build-guide.md) | Overlay setup, USE flags, emerge commands, keyword unmasking |
| [packages/README.md](packages/README.md) | Full dependency table and portage category assignments |

---

## Package Docs by Phase

### Phase 1 — Minimal Viable Node (QEMU/KVM + Web UI)

| Package doc | Portage atom | Status |
|-------------|-------------|--------|
| [pve-common](packages/pve-common.md) | `dev-perl/libpve-common-perl` | 🔲 ebuild needed |
| [pve-http-server](packages/pve-http-server.md) | `dev-perl/libpve-http-server-perl` | 🔲 ebuild needed |
| [pve-access-control](packages/pve-access-control.md) | `dev-perl/libpve-access-control` | 🔲 ebuild needed |
| [pve-guest-common](packages/pve-guest-common.md) | `dev-perl/libpve-guest-common-perl` | 🔲 ebuild needed |
| [pve-storage](packages/pve-storage.md) | `dev-perl/libpve-storage-perl` | 🔲 ebuild needed |
| [pve-qemu](packages/pve-qemu.md) | `app-emulation/pve-qemu-kvm` | 🔲 ebuild needed |
| [qemu-server](packages/qemu-server.md) | `app-emulation/qemu-server` | 🔲 ebuild needed |
| [pve-network](packages/pve-network.md) | `net-misc/libpve-network-perl` | 🔲 ebuild needed |
| [pve-manager](packages/pve-manager.md) | `sys-apps/pve-manager` | 🔲 ebuild needed |
| [extjs](packages/extjs.md) | `www-apps/libjs-extjs` | 🔲 ebuild needed |
| [proxmox-widget-toolkit](packages/proxmox-widget-toolkit.md) | `www-apps/proxmox-widget-toolkit` | 🔲 ebuild needed |
| [novnc-pve](packages/novnc-pve.md) | `www-apps/novnc-pve` | 🔲 ebuild needed |
| [pve-xtermjs](packages/pve-xtermjs.md) | `www-apps/pve-xtermjs` | 🔲 ebuild needed |
| [vncterm](packages/vncterm.md) | `app-emulation/vncterm` | 🔲 ebuild needed |

### Phase 2 — LXC Containers

| Package doc | Portage atom | Status |
|-------------|-------------|--------|
| [lxc](packages/lxc.md) | `app-emulation/lxc-pve` | 🔲 ebuild needed |
| [lxcfs](packages/lxcfs.md) | `app-emulation/lxcfs` | 🔲 ebuild needed |
| [pve-container](packages/pve-container.md) | `app-emulation/pve-container` | 🔲 ebuild needed |
| [pve-lxc-syscalld](packages/pve-lxc-syscalld.md) | `app-emulation/pve-lxc-syscalld` | 🔲 ebuild needed |

### Phase 3 — Clustering & HA

| Package doc | Portage atom | Status |
|-------------|-------------|--------|
| [corosync-pve](packages/corosync-pve.md) | `sys-cluster/corosync-pve` | 🔲 ebuild needed |
| [pve-cluster](packages/pve-cluster.md) | `sys-cluster/pve-cluster` | 🔲 ebuild needed |
| [pve-ha-manager](packages/pve-ha-manager.md) | `sys-cluster/pve-ha-manager` | 🔲 ebuild needed |

### Phase 4 — Advanced / Optional

| Package doc | Portage atom | Status |
|-------------|-------------|--------|
| [pve-firewall](packages/pve-firewall.md) | `net-firewall/pve-firewall` | 🔲 ebuild needed |
| [proxmox-acme](packages/proxmox-acme.md) | `dev-perl/libproxmox-acme-perl` | 🔲 ebuild needed |
| [proxmox-backup](packages/proxmox-backup.md) | `app-backup/proxmox-backup` | 🔲 ebuild needed |

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Ebuild complete and tested |
| 🔧 | Ebuild in progress |
| 🔲 | Ebuild not yet started |
| ⚠️ | Blocked by dependency |
