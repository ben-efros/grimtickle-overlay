# Package Index

Full list of pxvirt packages being ported to Gentoo, their portage atoms, dependency
relationships, and porting status.

---

## Portage Category Assignments

| Category | Packages |
|----------|---------|
| `dev-perl/` | All PVE Perl library packages (libpve-*, libproxmox-*) |
| `app-emulation/` | QEMU, LXC, qemu-server, vncterm, containers |
| `sys-cluster/` | Corosync, pve-cluster, pve-ha-manager, Ceph |
| `sys-apps/` | pve-manager (top-level daemon) |
| `net-misc/` | pve-network |
| `net-firewall/` | pve-firewall |
| `www-apps/` | Web UI assets: extjs, novnc, widget-toolkit, xtermjs |
| `app-backup/` | proxmox-backup |

---

## Full Dependency Table

> `→` means "required by". `[G]` = already in Gentoo main tree. `[O]` = needs overlay ebuild.

### Phase 1 — Minimal Viable Node

| Package | Portage atom | Type | Overlay? | Depends on |
|---------|-------------|------|----------|-----------|
| proxmox-perl-rs | `dev-perl/libproxmox-rs-perl` | Rust→Perl | [O] | `dev-lang/rust`, `dev-libs/openssl` |
| proxmox-ve-rs | `dev-perl/libpve-rs-perl` | Rust→Perl | [O] | `dev-perl/libproxmox-rs-perl` |
| pve-common | `dev-perl/libpve-common-perl` | Perl | [O] | `dev-perl/libproxmox-rs-perl`, `dev-perl/AnyEvent`, `dev-perl/JSON`, `dev-perl/Clone`, `dev-perl/Net-IP`, `dev-perl/Crypt-OpenSSL-RSA`, `dev-perl/IO-Stringy` |
| pve-http-server | `dev-perl/libpve-http-server-perl` | Perl | [O] | `dev-perl/libpve-common-perl`, `dev-perl/AnyEvent-HTTP` |
| pve-access-control | `dev-perl/libpve-access-control` | Perl | [O] | `dev-perl/libpve-common-perl`, `dev-perl/Authen-PAM`, `dev-perl/Crypt-OpenSSL-RSA` |
| pve-guest-common | `dev-perl/libpve-guest-common-perl` | Perl | [O] | `dev-perl/libpve-access-control`, `dev-perl/libpve-common-perl` |
| pve-storage | `dev-perl/libpve-storage-perl` | Perl | [O] | `dev-perl/libpve-common-perl`, `sys-fs/util-linux`, `sys-block/nbd` |
| pve-network | `net-misc/libpve-network-perl` | Perl | [O] | `dev-perl/libpve-common-perl`, `net-misc/bridge-utils` |
| pve-qemu | `app-emulation/pve-qemu-kvm` | C (autotools) | [O] | `app-emulation/spice`, `net-libs/gnutls`, `dev-libs/libusb`, `sys-libs/zlib`, `app-arch/lz4`, `sys-cluster/ceph` (USE=ceph) |
| qemu-server | `app-emulation/qemu-server` | Perl | [O] | `app-emulation/pve-qemu-kvm`, `dev-perl/libpve-storage-perl`, `dev-perl/libpve-common-perl`, `dev-perl/libpve-access-control`, `net-firewall/iptables` |
| extjs | `www-apps/libjs-extjs` | Static JS | [O] | none (arch-independent) |
| proxmox-widget-toolkit | `www-apps/proxmox-widget-toolkit` | Static JS | [O] | `www-apps/libjs-extjs` |
| novnc-pve | `www-apps/novnc-pve` | Static JS | [O] | none (arch-independent) |
| pve-xtermjs | `www-apps/pve-xtermjs` | Node.js/JS | [O] | `net-libs/nodejs` (build only) |
| vncterm | `app-emulation/vncterm` | C (CMake) | [O] | `net-libs/gnutls`, `x11-libs/libX11` |
| pve-manager | `sys-apps/pve-manager` | Perl | [O] | All of the above Phase 1 packages |

### Phase 2 — LXC Containers

| Package | Portage atom | Type | Overlay? | Depends on |
|---------|-------------|------|----------|-----------|
| lxc-pve | `app-emulation/lxc-pve` | C (autotools) | [O] | `sys-libs/libseccomp`, `sys-apps/apparmor` (USE=apparmor), `dev-libs/glib` |
| lxcfs | `app-emulation/lxcfs` | C (meson) | [G]/[O] | `sys-fs/fuse:3` |
| pve-lxc-syscalld | `app-emulation/pve-lxc-syscalld` | Rust | [O] | `dev-lang/rust`, `sys-libs/libseccomp` |
| pve-container | `app-emulation/pve-container` | Perl | [O] | `app-emulation/lxc-pve`, `dev-perl/libpve-guest-common-perl`, `dev-perl/libpve-storage-perl` |

### Phase 3 — Cluster & HA

| Package | Portage atom | Type | Overlay? | Depends on |
|---------|-------------|------|----------|-----------|
| libqb | `sys-libs/libqb` | C (autotools) | [G] | `sys-libs/zlib` — check Gentoo tree first |
| kronosnet | `sys-cluster/kronosnet` | C (autotools) | [G]/[O] | `net-libs/gnutls`, `dev-libs/nss` — check Gentoo tree |
| corosync-pve | `sys-cluster/corosync-pve` | C (autotools) | [O] | `sys-libs/libqb`, `sys-cluster/kronosnet`, `dev-libs/nss` |
| pve-cluster | `sys-cluster/pve-cluster` | C + Perl | [O] | `sys-cluster/corosync-pve`, `sys-fs/fuse:3`, `dev-libs/libgcrypt`, `dev-perl/libpve-common-perl` |
| pve-ha-manager | `sys-cluster/pve-ha-manager` | Perl | [O] | `sys-cluster/pve-cluster`, `dev-perl/libpve-common-perl` |

### Phase 4 — Advanced

| Package | Portage atom | Type | Overlay? | Depends on |
|---------|-------------|------|----------|-----------|
| pve-firewall | `net-firewall/pve-firewall` | Perl | [O] | `net-firewall/nftables`, `dev-perl/libpve-common-perl`, `dev-perl/libpve-cluster-perl` |
| proxmox-acme | `dev-perl/libproxmox-acme-perl` | Perl | [O] | `dev-perl/libpve-common-perl`, `net-misc/curl` |
| proxmox-backup | `app-backup/proxmox-backup` | Rust | [O] | `dev-lang/rust`, `dev-libs/openssl`, `sys-libs/zlib`, `dev-libs/popt` |
| ceph | `sys-cluster/ceph` | C++ (cmake) | ✅ [O] | See `sys-cluster/ceph` ebuild |

---

## Dependency Graph (Phase 1)

```
         proxmox-perl-rs
               │
          proxmox-ve-rs
               │
           pve-common ─────────────────────────┐
          /    │    \                           │
pve-http   pve-access  pve-storage   pve-network│
 -server   -control        │              │     │
     \        /            │              │     │
   pve-guest-common        │              │     │
               \           │              │     │
                └──────────┴──────────────┘     │
                           │                    │
                      qemu-server ◄─── pve-qemu │
                           │                    │
                       pve-manager ◄────────────┘
                      /    │    \    \
                   extjs  widget novnc vncterm
                         -toolkit  pve  xtermjs
```

---

## Packages Already in Gentoo Main Tree

Before writing overlay ebuilds, check these packages first — they may already exist in the
Gentoo tree and only need patching or version bumping:

| Package | Check command | Notes |
|---------|--------------|-------|
| `lxcfs` | `emerge -s lxcfs` | Likely `app-emulation/lxcfs` |
| `libqb` | `emerge -s libqb` | Likely `sys-libs/libqb` |
| `kronosnet` | `emerge -s kronosnet` | May be `sys-cluster/kronosnet` |
| `frr` | `emerge -s frr` | Free Range Routing, for BGP/EVPN SDN |
| `spiceterm` | `emerge -s spiceterm` | May not exist; pxvirt ships it |
| `swtpm` | `emerge -s swtpm` | For vTPM in VMs |

---

## Naming Conventions

When writing ebuilds for this overlay, follow these conventions:

- Use the upstream pxvirt package name as the ebuild directory name.
- Match Debian package names to Gentoo atoms where there is a clear mapping
  (e.g., `libpve-common-perl` → `dev-perl/libpve-common-perl`).
- For packages that install Perl libraries, use the `dev-perl/` category and inherit
  `perl-module`.
- For Rust packages (proxmox-*-rs), inherit `cargo` and vendor crates offline.
- For static JS/CSS assets (extjs, novnc, widget-toolkit), use `www-apps/` and inherit
  `webapp-config` if web server integration is needed.
